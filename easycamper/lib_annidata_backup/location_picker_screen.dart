import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'mapbox_config.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  MapboxMap? _mapboxMap;
  double _lat = 45.4642;
  double _lng = 9.1900;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _lat = widget.initialLat!;
      _lng = widget.initialLng!;
    }
    try {
      MapboxOptions.setAccessToken(mapboxAccessToken);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleziona posizione'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.of(context).pop({'lat': _lat, 'lng': _lng});
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(_lng, _lat)),
              zoom: 12.0,
            ),
            onMapCreated: (map) {
              _mapboxMap = map;
            },
            onCameraChangeListener: (event) async {
              if (_mapboxMap != null) {
                final state = await _mapboxMap!.getCameraState();
                _lat = state.center.coordinates.lat.toDouble();
                _lng = state.center.coordinates.lng.toDouble();
              }
            },
          ),
          const Center(
            child: Icon(Icons.location_on, size: 40, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
