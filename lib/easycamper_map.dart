import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

import 'api/spots_api.dart';
import 'spot_marker.dart';
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
  MapboxMapController? _mapController;
  List<SpotMarkerData> _spots = [];
  final Map<String, SpotMarkerData> _symbolIdToSpot = {};

  bool get _isMobile => widget.isMobile;

  // Permette alla schermata esterna di recentrare la camera sulla posizione passata
  Future<void> centerOn(double lat, double lng, {double zoom = 12}) async {
    if (_mapController == null) return;
    await _mapController!.moveCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), zoom),
    );
  }

  Future<void> reload() async {
    await _onMapIdle();
  }

  void _setLoading(bool value) {
    widget.onLoadingChanged?.call(value);
  }

  Future<void> _onMapIdle() async {
    // Carichiamo sempre dagli endpoint reali; i mock restano solo come fallback
    if (_mapController == null) return;

    _setLoading(true);
    try {
      final region = await _mapController!.getVisibleRegion();
      final latMin = region.southwest.latitude;
      final lngMin = region.southwest.longitude;
      final latMax = region.northeast.latitude;
      final lngMax = region.northeast.longitude;

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
        // Fallback ai mock solo se l’API fallisce
        spots = await _loadMockSpotsFromBundle(filters);
      }

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
        services: (m['services'] as List<dynamic>?)
                ?.map((s) => s.toString())
                .toList() ??
            const [],
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
        final anyRequired =
            filters.services.any((req) => setServizi.contains(req));
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
    if (_mapController == null) return;
    await _mapController!.clearSymbols();
    _symbolIdToSpot.clear();

    for (final spot in _spots) {
      final symbol = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(spot.latitude, spot.longitude),
          iconImage: 'assets/icons/marker.png',
          textField: spot.name,
          textOffset: const Offset(0, 1.2),
        ),
      );
      _symbolIdToSpot[symbol.id] = spot;
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
  Widget build(BuildContext context) {
    // La mappa reale è disponibile su tutte le piattaforme supportate.
    // Usiamo lo stesso widget Mapbox; il flag isMobile serve solo per UX esterna.
    return MapboxMap(
      accessToken: mapboxAccessToken,
      onMapCreated: (controller) {
        _mapController = controller;
        _mapController!.onSymbolTapped.add((symbol) {
          final spot = _symbolIdToSpot[symbol.id];
          if (spot != null) {
            widget.onSpotSelected(spot);
          }
        });
      },
      onCameraIdle: _onMapIdle,
      initialCameraPosition: const CameraPosition(
        target: LatLng(45.4642, 9.19),
        zoom: 8,
      ),
    );
  }
}
