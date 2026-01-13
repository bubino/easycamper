#!/usr/bin/env python3
"""Extract camper/camping POIs from an OSM PBF to NDJSON.

Strategy (recommended for large PBF):
1) Use `osmium tags-filter` (CLI) to create a small filtered PBF.
2) Use `osmium export` (CLI) to export to GeoJSON.
3) Convert GeoJSON Features to NDJSON lines for seeding the backend.

This avoids installing pyosmium.

Usage:
  python3 scripts/extract_spots_from_pbf.py \
      --input "/_dati_2/italy-260110.osm.pbf" \
      --workdir "/_dati_2/easycamper_seed" \
      --max 30000

Outputs:
- <workdir>/spots_filtered.osm.pbf
- <workdir>/spots_seed.ndjson

Requirements:
- osmium CLI available in PATH
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from typing import Any, Dict, Optional, Tuple


def _run(cmd: list[str]) -> None:
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"Command failed ({p.returncode}): {' '.join(cmd)}\n{p.stdout}")


def _first(*vals: Optional[str]) -> Optional[str]:
    for v in vals:
        if v is not None and str(v).strip() != "":
            return str(v)
    return None


def _is_rv_designated_parking(tags: Dict[str, Any]) -> bool:
    """True only for parking clearly dedicated to motorhomes/caravans.

    Keep this strict to avoid importing generic parkings.
    """

    def norm(v: Any) -> str:
        return str(v or "").strip().lower()

    motorhome = norm(tags.get("motorhome"))
    caravan = norm(tags.get("caravan"))
    parking = norm(tags.get("parking"))
    access = norm(tags.get("access"))

    if motorhome in ("yes", "designated"):
        return True
    if caravan in ("yes", "designated"):
        return True
    if parking in ("motorhome", "caravan"):
        return True

    # Heuristic: some parkings tag 'tourism=motorhome_stopover' but also amenity=parking
    if norm(tags.get("tourism")) == "motorhome_stopover":
        return True

    # If access is private/customers only and there is no explicit RV tag, skip.
    if access in ("private", "customers"):
        return False

    return False


def _spot_category(tags: Dict[str, Any]) -> str:
    """High-level category to support dedicated POIs (services vs stay)."""
    amenity = str(tags.get("amenity") or "").strip().lower()
    tourism = str(tags.get("tourism") or "").strip().lower()

    def _is_dump_like_waste_disposal(t: Dict[str, Any]) -> bool:
        # Only include waste_disposal when it's clearly RV sewage/black/grey water.
        def n(v: Any) -> str:
            return str(v or "").strip().lower()

        # Common tag patterns:
        # - amenity=waste_disposal + waste=sewage/blackwater/greywater
        # - sewage=yes
        # - sanitary_dump_station=yes (sometimes used as additional tag)
        waste = n(t.get("waste"))
        sewage = n(t.get("sewage"))
        sd = n(t.get("sanitary_dump_station"))
        wc = n(t.get("waste:human"))

        if waste in (
            "sewage",
            "blackwater",
            "greywater",
            "graywater",
            "black_water",
            "grey_water",
            "gray_water",
            "chemical_toilet",
            "cassette",
        ):
            return True

        if sewage in ("yes", "designated"):
            return True

        if sd in ("yes", "designated"):
            return True

        if wc in ("yes", "designated"):
            return True

        return False

    if amenity in ("sanitary_dump_station",):
        return "service_dump"
    if amenity == "waste_disposal" and _is_dump_like_waste_disposal(tags):
        return "service_dump"
    if amenity in ("water_point",):
        return "service_water"
    if amenity == "drinking_water" and (
        str(tags.get("motorhome") or "").strip().lower() in ("yes", "designated")
        or str(tags.get("caravan") or "").strip().lower() in ("yes", "designated")
    ):
        return "service_water"

    if tourism in ("camp_site", "caravan_site", "camp_pitch", "motorhome_stopover"):
        return "stay"

    if amenity == "parking" and _is_rv_designated_parking(tags):
        return "stay"

    return "other"


def _spot_type(tags: Dict[str, Any]) -> str:
    # If it's a dedicated service POI, map to a distinct type
    cat = _spot_category(tags)
    if cat == "service_dump":
        return "scarico"
    if cat == "service_water":
        return "carico_acqua"

    tourism = tags.get("tourism")
    if tourism == "camp_site":
        return "campeggio"

    if tourism in ("caravan_site", "camp_pitch"):
        return "area_sosta"

    if tourism == "motorhome_stopover":
        return "area_sosta"

    amenity = tags.get("amenity")
    if amenity == "parking" and _is_rv_designated_parking(tags):
        return "area_sosta"

    return "area_sosta"


def _services(tags: Dict[str, Any]) -> Dict[str, bool]:
    out: Dict[str, bool] = {}

    def yes(v: Any) -> bool:
        return str(v).strip().lower() in ("yes", "true", "1", "designated")

    amenity = tags.get("amenity")

    if str(amenity) == "water_point" or yes(tags.get("water_point", "")):
        out["water"] = True
    if str(amenity) == "drinking_water" and (
        yes(tags.get("motorhome")) or yes(tags.get("caravan")) or yes(tags.get("rv"))
    ):
        out["water"] = True

    if yes(tags.get("power_supply", "")) or yes(tags.get("electricity", "")):
        out["electricity"] = True

    if yes(tags.get("toilets", "")):
        out["toilet_public"] = True
    if yes(tags.get("shower", "")) or yes(tags.get("showers", "")):
        out["showers"] = True

    if str(amenity) in ("sanitary_dump_station", "waste_disposal"):
        out["grey_water"] = True
        out["black_water"] = True

    if str(tags.get("internet_access", "")).strip().lower() in ("yes", "wlan") or yes(tags.get("wifi", "")):
        out["wifi"] = True

    if yes(tags.get("pets", "")) or yes(tags.get("dogs", "")):
        out["animals"] = True

    return out


def _relevant(tags: Dict[str, Any]) -> bool:
    return _spot_category(tags) != "other"


def _centroid_from_coords(coords: Any) -> Optional[Tuple[float, float]]:
    def _is_num(x: Any) -> bool:
        return isinstance(x, (int, float)) and not isinstance(x, bool)

    def _collect_points(node: Any, out: list[Tuple[float, float]]) -> None:
        # Leaf: [lon, lat]
        if (
            isinstance(node, list)
            and len(node) >= 2
            and _is_num(node[0])
            and _is_num(node[1])
        ):
            out.append((float(node[0]), float(node[1])))
            return

        # Recurse lists
        if isinstance(node, list):
            for child in node:
                _collect_points(child, out)

    def mean_any(n: Any) -> Optional[Tuple[float, float]]:
        pts: list[Tuple[float, float]] = []
        _collect_points(n, pts)
        if not pts:
            return None
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        return (sum(xs) / len(xs), sum(ys) / len(ys))

    if not coords:
        return None

    # Best-effort: compute mean of all collected points.
    return mean_any(coords)


def _require_osmium() -> None:
    if shutil.which("osmium") is None:
        raise RuntimeError("osmium CLI not found in PATH. Install with: brew install osmium-tool")


def _filter_pbf(input_pbf: str, filtered_pbf: str) -> None:
    cmd = [
        "osmium",
        "tags-filter",
        input_pbf,
        "n/tourism=camp_site",
        "n/tourism=caravan_site",
        "n/tourism=camp_pitch",
        "n/tourism=motorhome_stopover",
        "n/amenity=sanitary_dump_station",
        "n/amenity=drinking_water",
        "n/amenity=waste_disposal",
        "n/amenity=parking",
        "w/tourism=camp_site",
        "w/tourism=caravan_site",
        "w/tourism=camp_pitch",
        "w/tourism=motorhome_stopover",
        "w/amenity=sanitary_dump_station",
        "w/amenity=drinking_water",
        "w/amenity=waste_disposal",
        "w/amenity=parking",
        "-o",
        filtered_pbf,
        "--overwrite",
    ]
    _run(cmd)


def _export_geojson(filtered_pbf: str, geojson_path: str) -> None:
    cmd = [
        "osmium",
        "export",
        filtered_pbf,
        "-f",
        "geojson",
        "-o",
        geojson_path,
        "--overwrite",
    ]
    _run(cmd)


def _geojson_to_ndjson(geojson_path: str, ndjson_path: str, max_items: int) -> int:
    with open(geojson_path, "r", encoding="utf-8") as fp:
        data = json.load(fp)

    features = data.get("features")
    if not isinstance(features, list):
        raise RuntimeError("Unexpected geojson format: missing features[]")

    def stable_id(name: str, lat: float, lon: float, typ: str) -> str:
        key = f"{typ}|{name}|{lat:.6f}|{lon:.6f}"
        return "osmx:" + str(abs(hash(key)))

    written = 0
    with open(ndjson_path, "w", encoding="utf-8") as out:
        for f in features:
            if max_items and written >= max_items:
                break

            props = f.get("properties") or {}
            if not isinstance(props, dict):
                continue

            tags = props

            if not _relevant(tags):
                continue

            geom = f.get("geometry") or {}
            gtype = geom.get("type")
            coords = geom.get("coordinates")

            lon_f: Optional[float] = None
            lat_f: Optional[float] = None

            if gtype == "Point" and isinstance(coords, list) and len(coords) >= 2:
                try:
                    lon_f = float(coords[0])
                    lat_f = float(coords[1])
                except Exception:
                    continue
            else:
                c = _centroid_from_coords(coords)
                if c is None:
                    continue
                lon_f, lat_f = c

            name = _first(tags.get("name"), tags.get("name:it"), tags.get("brand"))

            tourism = str(tags.get("tourism") or "").strip()
            amenity = str(tags.get("amenity") or "").strip()

            if not name:
                # For service POIs (dump/water) we still want to import even when unnamed.
                cat = _spot_category(tags)
                if cat in ("service_dump", "service_water"):
                    if cat == "service_dump":
                        name = "Scarico camper"
                    else:
                        name = "Carico acqua"
                else:
                    # For stay POIs keep requiring a name (prevents lots of generic objects).
                    if tourism not in (
                        "camp_site",
                        "caravan_site",
                        "camp_pitch",
                        "motorhome_stopover",
                    ):
                        continue
                    name = f"{tourism.replace('_', ' ')}"

            typ = _spot_type(tags)
            osm_pk = stable_id(name, lat_f, lon_f, typ)

            spot = {
                "id": osm_pk,
                "name": name,
                "latitude": lat_f,
                "longitude": lon_f,
                "type": typ,
                "services": _services(tags),
                "shortDescription": _first(tags.get("description"), tags.get("note"), tags.get("operator")),
                "tags": {
                    k: tags[k]
                    for k in (
                        "tourism",
                        "amenity",
                        "motorhome",
                        "caravan",
                        "access",
                        "water_point",
                        "drinking_water",
                        "waste",
                        "sewage",
                        "sanitary_dump_station",
                    )
                    if k in tags
                },
            }

            out.write(json.dumps(spot, ensure_ascii=False) + "\n")
            written += 1

    return written


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="Path to .osm.pbf")
    ap.add_argument("--workdir", required=True, help="Work directory (prefer external disk)")
    ap.add_argument("--max", type=int, default=30000, help="Max number of POIs to export")
    ap.add_argument("--keep-geojson", action="store_true", help="Keep intermediate GeoJSON")
    args = ap.parse_args()

    _require_osmium()

    in_path = os.path.expanduser(args.input)
    if not os.path.exists(in_path):
        print(f"Input not found: {in_path}", file=sys.stderr)
        return 2

    workdir = os.path.expanduser(args.workdir)
    os.makedirs(workdir, exist_ok=True)

    filtered_pbf = os.path.join(workdir, "spots_filtered.osm.pbf")
    geojson_path = os.path.join(workdir, "spots_filtered.geojson")
    ndjson_path = os.path.join(workdir, "spots_seed.ndjson")

    print("[1/3] Filtering PBF...")
    _filter_pbf(in_path, filtered_pbf)

    print("[2/3] Exporting GeoJSON...")
    _export_geojson(filtered_pbf, geojson_path)

    print("[3/3] Converting to NDJSON...")
    written = _geojson_to_ndjson(geojson_path, ndjson_path, max_items=max(args.max, 0))

    if not args.keep_geojson:
        try:
            os.remove(geojson_path)
        except Exception:
            pass

    print(f"Done. Wrote {written} POIs to: {ndjson_path}")
    print(f"Filtered PBF kept at: {filtered_pbf}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
