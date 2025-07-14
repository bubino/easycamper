# EasyCamper – Roadmap & Checklist (2025-Q3/Q4)

## 0. Vision
«Un’unica app per camperisti con routing “camper-aware”, community spot, prezzi carburante in tempo reale e navigazione integrata in-car».

---

## 1 Infra & Storage ‑ PRIORITÀ ALTA (Sprint 1)
- [ ] VPS IONOS unico nodo (8 GB RAM)  
- [ ] **MinIO** Docker  
  ```bash
  docker run -d --name minio \
    -e MINIO_ROOT_USER=easyadmin \
    -e MINIO_ROOT_PASSWORD=******** \
    -v /opt/minio/data:/data \
    -p 9000:9000 -p 9090:9090 \
    quay.io/minio/minio server /data --console-address ":9090"
  ```
- [ ] Bucket `easycamper-media` + policy read-only public
- [ ] Express → `services/fileStorage.js` (minio-sdk)  
  – `uploadPresigned()` – `getSignedUrl()` – `deleteObject()`
- [ ] ENV ➜ `MINIO_ENDPOINT`, `MINIO_KEY`, `MINIO_SECRET`, `MINIO_BUCKET`

---

## 2 GraphHopper Import & Sharding – ALTA (Sprint 1-2)
| Shard | BBox | Porta |
|-------|------|-------|
| Nord  | 60 N-44 N | 8989 |
| Centro| 44 N-40 N | 8990 |
| Sud   | 40 N-30 N | 8991 |

Script `scripts/build_shards.sh`  
1. `osmium extract europe-latest.osm.pbf -p nord.poly -o nord.osm.pbf`  
2. `graphhopper.sh import nord.yml` (`-Xmx6g`)  
3. Tar cache → `/opt/graph-cache/nord`

NGINX upstream intelligent dispatch (lat/lon in query).

---

## 3 Routing Camper-Aware – ALTA (Sprint 2)
- [ ] `camper_eco`, `camper_scenic`, `camper_fast` in `custom_model.json`
  - usa `priority`, `speed`, `areas`
  - **niente** restrictions obsolete
- [ ] `/api/route` payload
  ```json
  { "points":[[lat,lon],…],
    "profile":"camper_eco",
    "dimensions":{ "height":3.1,"width":2.4,"length":7.4,"weight":3.5 }
  }
  ```
- [ ] Middleware Express che mappa -> shard + profilo
- [ ] Benchmark < 600 ms median VPS

---

## 4 Mobile Map & In-Car – MEDIA (Sprint 3)
- [ ] Flutter Mapbox layer spot (user + third-party)  
- [ ] Bottom-sheet “Naviga qui” → /api/route  
- [ ] Mapbox Navigation SDK – CarPlay / Android Auto module  
- [ ] Offline cache tile (MapboxOfflineRegion) + Hive for spots

---

## 5 Camper DB & Vehicle Models – MEDIA (Sprint 3)
- Tabella `VehicleModels`
- Service `vehicleSpecFetch.js` → CarQuery/NHTSA → cache
- Autocomplete `/vehicle-models`
- Batch seed 2010-oggi

---

## 6 Fuel Stations & Pricing – MEDIA (Sprint 4)
- Service `fuelService.js` fetch Openfuel.io → cron 6 h
- Layer Mapbox + popup prezzi
- Cloud Functions → FCM push «Diesel < 1.78€ a 5 km»

---

## 7 Observability – MEDIA (Sprint 4)
- Pino → **Loki** (Grafana Cloud free tier)  
- Metrics `/metrics` → **Prometheus** + Alertmanager  
- Tracing OTel → **Grafana Tempo** (Docker)  
- Sentry free plan (mobile + backend)

---

## 8 CI/CD & Backup – BASSA (Sprint 5)
- GitHub Actions  
  1. lint/test  
  2. docker build/push `ghcr.io/bubino/easycamper-api`  
  3. SSH ➜ `docker pull && docker compose up -d`
- Fastlane nightly beta TestFlight / Play Internal
- `cron.daily`  
  ```bash
  pg_dump easycamper | gzip > /opt/backup/pg_$(date +%F).sql.gz
  rclone copy /opt/backup minio:easycamper-backup
  ```
---

## 9 UX Premium – BASSA (Sprint 6)
- Live Activities / Widgets (ETA + prezzo carburante)
- Wizard “Aggiungi spot” (3 step, validazione inline)
- AI tagging foto (TFLite on-device, offline)

---

## Checklist Sicurezza
- [ ] helmet ✔️
- [ ] cors whitelist ✔️
- [ ] express-rate-limit ✔️
- [ ] xss-clean + hpp ✔️
- [ ] JWT 15 min + refresh 30 gg
- [ ] Secrets in `/opt/easycamper/.secrets` (no git)

---

## Milestones (Gantt semplificato)
```
Wk1  Wk2  Wk3  Wk4  Wk5  Wk6  Wk7  Wk8  Wk9
[Infra/MinIO]■■■■
[Shard GH ]     ■■■■
[Routing   ]         ■■■
[Map UI    ]            ■■■
[Camper DB ]               ■■
[Fuel Price]                 ■■
[Observab. ]                    ■■
[CI/CD     ]                       ■■
[UX Prem.]                           ■■
```

> **Target beta pubblica**: fine settimana 9.
