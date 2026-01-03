import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';

import 'api/spot_dto.dart';

enum CamperRouteType { eco, fast, scenic }

class NavigationOptionsScreen extends StatefulWidget {
  final SpotDto spot;

  const NavigationOptionsScreen({super.key, required this.spot});

  @override
  State<NavigationOptionsScreen> createState() => _NavigationOptionsScreenState();
}

class _NavigationOptionsScreenState extends State<NavigationOptionsScreen> {
  CamperRouteType? _selected;
  MapboxMap? _previewMap;
  PointAnnotationManager? _annoMgr;

  Future<void> _ensureManagers() async {
    final map = _previewMap;
    if (map == null) return;
    _annoMgr ??= await map.annotations.createPointAnnotationManager();
  }

  Future<Uint8List?> _loadMarkerBytes(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  String _assetForSpotType(String type) {
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

  Future<void> _renderDestinationMarker() async {
    await _ensureManagers();
    final mgr = _annoMgr;
    if (mgr == null) return;
    await mgr.deleteAll();

    final asset = _assetForSpotType(widget.spot.type);
    final bytes = await _loadMarkerBytes(asset) ??
        await _loadMarkerBytes('assets/icons/markers/icon_p.png');

    await mgr.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(widget.spot.lng, widget.spot.lat),
        ),
        image: bytes,
        iconSize: 1.6,
      ),
    );
  }

  void _onMapCreated(MapboxMap map) async {
    _previewMap = map;

    // Wait a tick to ensure style is applied before creating managers/annotations.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _renderDestinationMarker();

    _previewMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(widget.spot.lng, widget.spot.lat)),
        zoom: 11.0,
      ),
    );
  }

  Future<void> _renderRoutePreviewIfPossible() async {
    final map = _previewMap;
    if (map == null) return;

    // Placeholder: for now we don't call routing APIs.
    // In the future we’ll call the routing backend and draw the returned polyline.
    // Here we just keep the destination marker visible.
    await _renderDestinationMarker();
  }

  @override
  void dispose() {
    _annoMgr?.deleteAll();
    _annoMgr = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF071814);
    const primary = Color(0xFF1b7f6b);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Navigazione',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MapWidget(
                  key: const ValueKey('navigation_preview_map'),
                  cameraOptions: CameraOptions(
                    center: Point(coordinates: Position(widget.spot.lng, widget.spot.lat)),
                    zoom: 11.0,
                  ),
                  styleUri: MapboxStyles.MAPBOX_STREETS,
                  onMapCreated: _onMapCreated,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Navigazione verso ${widget.spot.name}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Scegli il tipo di percorso',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildOption(
              context,
              type: CamperRouteType.eco,
              title: 'Camper Eco',
              subtitle: 'Percorso ottimizzato per consumi e impatto ambientale',
              icon: Icons.eco,
            ),
            const SizedBox(height: 8),
            _buildOption(
              context,
              type: CamperRouteType.fast,
              title: 'Camper Fast',
              subtitle: 'Percorso più veloce possibile verso la destinazione',
              icon: Icons.speed,
            ),
            const SizedBox(height: 8),
            _buildOption(
              context,
              type: CamperRouteType.scenic,
              title: 'Camper Scenic',
              subtitle: 'Percorso panoramico con strade più suggestive',
              icon: Icons.landscape,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
            ),
            onPressed: _selected == null
                ? null
                : () {
                    // TODO: agganciare al sistema di routing reale.
                    debugPrint('START NAVIGATION to ${widget.spot.name} with $_selected');
                    Navigator.of(context).pop();
                  },
            child: const Text('AVVIA NAVIGAZIONE'),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required CamperRouteType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _selected == type;

    return InkWell(
      onTap: () async {
        setState(() => _selected = type);
        await _renderRoutePreviewIfPossible();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0d221a),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF1b7f6b) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Radio<CamperRouteType>(
              value: type,
              groupValue: _selected,
              onChanged: (value) {
                setState(() => _selected = value);
              },
              activeColor: const Color(0xFF1b7f6b),
            ),
          ],
        ),
      ),
    );
  }
}