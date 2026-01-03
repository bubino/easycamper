import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'api/spots_api.dart';
import 'mapbox_config.dart';

// Rende il tipo di filtri riutilizzabile da altre schermate
class SpotFilters {
  final List<String> types;
  final List<String> services;
  final double? minRating;

  const SpotFilters({
    required this.types,
    required this.services,
    required this.minRating,
  });
}

typedef SpotFiltersBuilder = SpotFilters Function();

class EasyCamperMap extends StatefulWidget {
  final SpotsApiClient spotsApiClient;
  final bool isMobile;
  final SpotFiltersBuilder filtersBuilder;
  final ValueChanged<List<SpotMarkerData>> onSpotsChanged;
  final ValueChanged<SpotMarkerData> onSpotSelected;
  final ValueChanged<bool>? onLoadingChanged;

  const EasyCamperMap({
    super.key,
    required this.spotsApiClient,
    required this.isMobile,
    required this.filtersBuilder,
    required this.onSpotsChanged,
    required this.onSpotSelected,
    this.onLoadingChanged,
  });

  @override
  State<EasyCamperMap> createState() => EasyCamperMapState();
}

class EasyCamperMapState extends State<EasyCamperMap> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnoManager;

  List<SpotMarkerData> _spots = [];
  final Map<String?, SpotMarkerData> _annotationIdToSpot = {};

  int _refreshToken = 0;

  final Map<String, Uint8List?> _markerBytesByAsset = {};

  String? _lastRenderedSignature;

  // Only show/fetch POIs when user is sufficiently zoomed in.
  // Prevents loading hundreds/thousands of items at startup.
  static const double _minZoomToFetchPois = 9.5;

  bool _refreshInFlight = false;

  Future<Uint8List?> _loadMarkerBytes(String assetPath) async {
    if (_markerBytesByAsset.containsKey(assetPath)) {
      return _markerBytesByAsset[assetPath];
    }
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      _markerBytesByAsset[assetPath] = bytes;
      return bytes;
    } catch (_) {
      _markerBytesByAsset[assetPath] = null;
      return null;
    }
  }

  String _assetForSpotType(String? type) {
    switch (type) {
      case 'campeggio':
        return 'assets/icons/markers/icon_c.png';
      case 'agricampeggio':
        return 'assets/icons/markers/icon_ar.png';
      case 'area_sosta':
      default:
        return 'assets/icons/markers/icon_p.png';
    }
  }

  String _spotsSignature(List<SpotMarkerData> spots) {
    // Stable signature to detect no-op refreshes
    return spots
        .map((s) => '${s.id}:${s.latitude.toStringAsFixed(5)},${s.longitude.toStringAsFixed(5)}')
        .join('|');
  }

  // Permette alla schermata esterna di recentrare la camera sulla posizione passata
  Future<void> centerOn(double lat, double lng, {double zoom = 12}) async {
    final map = _mapboxMap;
    if (map == null) return;

    map.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      ),
    );
  }

  Future<void> reload() async {
    // Force next refresh to re-render even if signature matches
    _lastRenderedSignature = null;
    _onMapIdle();
  }

  void _setLoading(bool value) {
    widget.onLoadingChanged?.call(value);
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // token (set globale)
    MapboxOptions.setAccessToken(mapboxAccessToken);

    final annos = mapboxMap.annotations;
    _pointAnnoManager = await annos.createPointAnnotationManager();

    // Tap events: in 2.0.0 il listener consigliato è tapListener. (tapEvents può non essere presente)
    _pointAnnoManager?.addOnPointAnnotationClickListener(
      _PointAnnoClickListener(_annotationIdToSpot, widget.onSpotSelected),
    );

    await _refreshSpotsForCurrentCamera();
  }

  void _onMapIdle() {
    // debounce/coalescing: se arrivano più idle ravvicinati, eseguiamo solo l'ultimo
    final token = ++_refreshToken;
    Future<void>.delayed(const Duration(milliseconds: 450)).then((_) {
      if (!mounted) return;
      if (token != _refreshToken) return;
      _refreshSpotsForCurrentCamera();
    });
  }

  Future<void> _refreshSpotsForCurrentCamera() async {
    final map = _mapboxMap;
    if (map == null) return;

    // Prevent overlapping refreshes (e.g. many idle events in a short time).
    if (_refreshInFlight) return;
    _refreshInFlight = true;

    final token = _refreshToken;

    _setLoading(true);
    try {
      final state = await map.getCameraState();

      final zoom = state.zoom;
      if (zoom < _minZoomToFetchPois) {
        // Too zoomed out: clear markers to avoid clutter/lag.
        if (!mounted) return;
        if (token != _refreshToken) return;

        if (_spots.isNotEmpty) {
          setState(() {
            _spots = [];
          });
          await _renderSpotsOnMap();
          _lastRenderedSignature = '';
          widget.onSpotsChanged(const []);
        }
        return;
      }

      // bbox reale della viewport (normalizzato)
      final bounds =
          await map.coordinateBoundsForCamera(state.toCameraOptions());
      final sw = bounds.southwest;
      final ne = bounds.northeast;

      double latMin = sw.coordinates.lat.toDouble();
      double lngMin = sw.coordinates.lng.toDouble();
      double latMax = ne.coordinates.lat.toDouble();
      double lngMax = ne.coordinates.lng.toDouble();

      // Normalize in case values are swapped
      if (latMin > latMax) {
        final tmp = latMin;
        latMin = latMax;
        latMax = tmp;
      }
      if (lngMin > lngMax) {
        final tmp = lngMin;
        lngMin = lngMax;
        lngMax = tmp;
      }

      final filters = widget.filtersBuilder();

      List<SpotMarkerData> spots;
      try {
        spots = await widget.spotsApiClient.fetchSpotsForBBox(
          latMin: latMin,
          lngMin: lngMin,
          latMax: latMax,
          lngMax: lngMax,
          types: filters.types,
          services: filters.services,
          minRating: filters.minRating,
        );
      } catch (e) {
        // ignore: avoid_print
        print('SPOTS DEBUG: backend fetch failed: $e');
        spots = await _loadMockSpotsFromBundle(filters);
      }

      // ignore: avoid_print
      print(
          'SPOTS DEBUG: bbox=[$latMin,$lngMin,$latMax,$lngMax] -> ${spots.length} spots');

      if (!mounted) return;
      if (token != _refreshToken) return;

      final sig = _spotsSignature(spots);
      if (_lastRenderedSignature == sig) {
        widget.onSpotsChanged(spots);
        return;
      }

      setState(() {
        _spots = spots;
      });

      await _renderSpotsOnMap();
      _lastRenderedSignature = sig;
      widget.onSpotsChanged(spots);
    } finally {
      _setLoading(false);
      _refreshInFlight = false;
    }
  }

  Future<List<SpotMarkerData>> _loadMockSpotsFromBundle(
    SpotFilters filters,
  ) async {
    final raw = await rootBundle.loadString('mock_data/spot.json');
    final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;

    final allSpots = jsonList.map((e) {
      final m = e as Map<String, dynamic>;
      return SpotMarkerData(
        id: m['id'] as String,
        name: m['name'] as String,
        latitude: (m['lat'] as num).toDouble(),
        longitude: (m['lng'] as num).toDouble(),
        shortDescription: m['description'] as String?,
        type: m['type'] as String?,
        services: (m['services'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? const [],
        rating: (m['rating'] as num?)?.toDouble(),
      );
    }).toList();

    return allSpots.where((s) {
      // Tipo area
      if (filters.types.isNotEmpty) {
        final mappedType = _mapTipoAreaToBackend(filters.types);
        if (s.type == null || !mappedType.contains(s.type)) {
          return false;
        }
      }
      // Servizi
      if (filters.services.isNotEmpty) {
        final setServizi = s.services.toSet();
        final anyRequired = filters.services.any((req) => setServizi.contains(req));
        if (!anyRequired) return false;
      }
      // Rating
      if (filters.minRating != null && filters.minRating! > 0) {
        final r = s.rating ?? 0;
        if (r < filters.minRating!) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _renderSpotsOnMap() async {
    final mgr = _pointAnnoManager;
    if (mgr == null) return;

    _annotationIdToSpot.clear();
    await mgr.deleteAll();

    final annotations = <PointAnnotationOptions>[];
    for (final spot in _spots) {
      final asset = _assetForSpotType(spot.type);
      final bytes = await _loadMarkerBytes(asset) ??
          await _loadMarkerBytes('assets/icons/markers/icon_p.png');

      annotations.add(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(spot.longitude, spot.latitude)),
          image: bytes,
          // Bigger markers to make tapping easier on real iPhone.
          iconSize: 2.6,
        ),
      );
    }

    final created = await mgr.createMulti(annotations);
    for (var i = 0; i < created.length; i++) {
      final dynamic anno = created[i];
      final String? id = (anno as dynamic).id as String?;
      if (id != null) {
        _annotationIdToSpot[id] = _spots[i];
      }
    }
  }

  List<String> _mapTipoAreaToBackend(List<String> tipiUi) {
    final mapped = <String>[];
    for (final t in tipiUi) {
      switch (t) {
        case 'Area di sosta':
          mapped.add('area_sosta');
          break;
        case 'Campeggio':
          mapped.add('campeggio');
          break;
        case 'Agricampeggio':
          mapped.add('agricampeggio');
          break;
        default:
          break;
      }
    }
    return mapped;
  }

  @override
  void dispose() {
    _pointAnnoManager?.deleteAll();
    _pointAnnoManager = null;
    _mapboxMap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('easycamper_map'),
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(9.19, 45.4642)),
        zoom: 8.0,
      ),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      onMapCreated: _onMapCreated,
      onMapIdleListener: (_) => _onMapIdle(),
    );
  }
}

class _PointAnnoClickListener extends OnPointAnnotationClickListener {
  _PointAnnoClickListener(this._byId, this._onSelected);

  final Map<String?, SpotMarkerData> _byId;
  final ValueChanged<SpotMarkerData> _onSelected;

  @override
  bool onPointAnnotationClick(PointAnnotation annotation) {
    final spot = _byId[annotation.id];
    if (spot != null) {
      _onSelected(spot);
      return true;
    }
    return false;
  }
}
