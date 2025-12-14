import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'mapbox_config.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  MapboxMapController? _mapController;
  late double _lat;
  late double _lng;

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat ?? 45.4642;
    _lng = widget.initialLng ?? 9.1900;
  }

  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
  }

  void _onCameraIdle() {
    if (_mapController == null) return;
    final position = _mapController!.cameraPosition;
    if (position != null) {
      setState(() {
        _lat = position.target.latitude;
        _lng = position.target.longitude;
      });
    }
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
          MapboxMap(
            accessToken: mapboxAccessToken,
            styleString: MapboxStyles.MAPBOX_STREETS,
            initialCameraPosition: CameraPosition(
              target: LatLng(_lat, _lng),
              zoom: 12.0,
            ),
            onMapCreated: _onMapCreated,
            onCameraIdle: _onCameraIdle,
          ),
          const Center(
            child: Icon(Icons.location_on, size: 40, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
