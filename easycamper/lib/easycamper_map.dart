import 'dart:convert';
import 'dart:math'; // Aggiunto per Point

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
  bool _imagesLoaded = false;
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

      debugPrint('Fetching spots for bbox: $latMin, $lngMin, $latMax, $lngMax');

      final filters = widget.filtersBuilder();

      // Usiamo direttamente l'API, senza fallback ai mock (come richiesto)
      final spots = await widget.spotsApiClient.fetchSpotsForBBox(
        latMin: latMin,
        lngMin: lngMin,
        latMax: latMax,
        lngMax: lngMax,
        types: filters.types,
        services: filters.services,
        minRating: filters.minRating,
      );

      debugPrint('Fetched ${spots.length} spots');

      if (!mounted) return;

      setState(() {
        _spots = spots;
      });

      await _renderSpotsOnMap();
      widget.onSpotsChanged(spots);
    } catch (e) {
      debugPrint('Error fetching spots: $e');
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  void _onStyleLoaded() {
    debugPrint('Map Style Loaded');
    
    // Tentativo di rimuovere le etichette dei POI nativi per pulire la mappa
    try {
      _mapController?.removeLayer("poi-label");
    } catch (e) {
      debugPrint("Impossibile rimuovere poi-label: $e");
    }

    _ensureImagesLoaded().then((_) {
      if (_spots.isNotEmpty) {
        _renderSpotsOnMap();
      } else {
        _onMapIdle();
      }
    });
  }

  Future<void> _ensureImagesLoaded() async {
    if (_imagesLoaded || _mapController == null) return;
    try {
      debugPrint('Loading map icons...');
      await _addImageFromAsset('icon_p', 'assets/icons/icon_p.png');
      await _addImageFromAsset('icon_c', 'assets/icons/icon_c.png');
      await _addImageFromAsset('icon_apn', 'assets/icons/icon_apn.png');
      _imagesLoaded = true;
      debugPrint('Map icons loaded.');
    } catch (e) {
      debugPrint('Errore caricamento icone mappa: $e');
    }
  }

  Future<void> _addImageFromAsset(String name, String assetPath) async {
    final ByteData bytes = await rootBundle.load(assetPath);
    final Uint8List list = bytes.buffer.asUint8List();
    await _mapController!.addImage(name, list);
  }

  Future<void> _renderSpotsOnMap() async {
    if (_mapController == null) return;
    
    await _ensureImagesLoaded();
    
    await _mapController!.clearSymbols();
    _symbolIdToSpot.clear();

    debugPrint('Rendering ${_spots.length} spots on map');

    for (final spot in _spots) {
      final type = (spot.type ?? '').toLowerCase().trim();
      
      String iconName = 'icon_p'; 
      if (type.contains('campeggio') || type.contains('camping')) iconName = 'icon_c';
      if (type.contains('agricampeggio') || type.contains('agricamping')) iconName = 'icon_apn';

      final symbol = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(spot.latitude, spot.longitude),
          iconImage: iconName, // Usa l'icona corretta
          iconSize: 2.0,       // Dimensione corretta
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
    return MapboxMap(
      accessToken: mapboxAccessToken,
      compassEnabled: true,
      compassViewPosition: CompassViewPosition.TopRight,
      compassViewMargins: const Point(16, 150), // Spostata più in basso
      onMapCreated: (controller) {
        _mapController = controller;
        _mapController!.onSymbolTapped.add((symbol) {
          final spot = _symbolIdToSpot[symbol.id];
          if (spot != null) {
            widget.onSpotSelected(spot);
          }
        });
      },
      onStyleLoadedCallback: _onStyleLoaded,
      onCameraIdle: _onMapIdle,
      initialCameraPosition: const CameraPosition(
        target: LatLng(45.4642, 9.19),
        zoom: 8,
      ),
      styleString: MapboxStyles.MAPBOX_STREETS,
    );
  }
}
