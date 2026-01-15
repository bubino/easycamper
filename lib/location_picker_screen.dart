import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  MapboxMap? _mapboxMap;

  // Stato corrente della camera (usato per restituire la posizione scelta)
  double? _currentLat;
  double? _currentLng;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.initialLat;
    _currentLng = widget.initialLng;
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;

    // Se abbiamo una posizione iniziale, centriamo lì la camera
    final lat = widget.initialLat ?? 45.4642;
    final lng = widget.initialLng ?? 9.19;

    setState(() {
      _currentLat = lat;
      _currentLng = lng;
    });

    _mapboxMap!.setCamera(
      CameraOptions(center: Point(coordinates: Position(lng, lat)), zoom: 13.0),
    );
  }

  Future<void> _updateCurrentCameraPosition() async {
    if (_mapboxMap == null) return;
    final state = await _mapboxMap!.getCameraState();
    final center = state.center;
    setState(() {
      _currentLat = center.coordinates.lat.toDouble();
      _currentLng = center.coordinates.lng.toDouble();
    });
  }

  Future<void> _confirmSelection() async {
    await _updateCurrentCameraPosition();
    if (_currentLat == null || _currentLng == null) return;

    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(<String, double>{'lat': _currentLat!, 'lng': _currentLng!});
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF071814);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        title: const Text(
          'Scegli posizione',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _confirmSelection,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              cameraOptions: CameraOptions(
                // Rispetta iniziale se presente.
                center: Point(
                  coordinates: Position(
                    (widget.initialLng ?? 9.19),
                    (widget.initialLat ?? 45.4642),
                  ),
                ),
                zoom:
                    widget.initialLat != null && widget.initialLng != null
                        ? 13.0
                        : 5.0,
              ),
              styleUri: MapboxStyles.MAPBOX_STREETS,
              onMapCreated: _onMapCreated,
              onCameraChangeListener: (cameraChanged) {
                final center = cameraChanged.cameraState.center;
                final lat = center.coordinates.lat.toDouble();
                final lng = center.coordinates.lng.toDouble();

                // Senza setState, la label in basso resta ferma.
                if (!mounted) return;
                setState(() {
                  _currentLat = lat;
                  _currentLng = lng;
                });
              },
            ),
          ),
          // Marker fisso al centro
          const IgnorePointer(
            ignoring: true,
            child: Center(
              child: Icon(Icons.place, color: Colors.redAccent, size: 36),
            ),
          ),
          // Box informativo in basso con le coordinate correnti
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _currentLat != null && _currentLng != null
                    ? 'Lat: ${_currentLat!.toStringAsFixed(5)}, Lng: ${_currentLng!.toStringAsFixed(5)}'
                    : 'Sposta la mappa per scegliere la posizione',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
