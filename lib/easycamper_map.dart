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

  bool get _isMobile => widget.isMobile;

  int _refreshToken = 0;

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
    Future<void>.delayed(const Duration(milliseconds: 250)).then((_) {
      if (!mounted) return;
      if (token != _refreshToken) return;
      _refreshSpotsForCurrentCamera();
    });
  }

  Future<void> _refreshSpotsForCurrentCamera() async {
    final map = _mapboxMap;
    if (map == null) return;

    _setLoading(true);
    try {
      final state = await map.getCameraState();

      // bbox reale della viewport
      final bounds = await map.coordinateBoundsForCamera(state.toCameraOptions());
      final sw = bounds.southwest;
      final ne = bounds.northeast;

      final latMin = sw.coordinates.lat.toDouble();
      final lngMin = sw.coordinates.lng.toDouble();
      final latMax = ne.coordinates.lat.toDouble();
      final lngMax = ne.coordinates.lng.toDouble();

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
      } catch (_) {
        spots = await _loadMockSpotsFromBundle(filters);
      }

      if (!mounted) return;
      setState(() {
        _spots = spots;
      });

      await _renderSpotsOnMap();
      widget.onSpotsChanged(spots);
    } finally {
      _setLoading(false);
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
      annotations.add(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(spot.longitude, spot.latitude)),
          textField: spot.name,
          textOffset: [0.0, 1.2],
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
