import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'mapbox_config.dart';

import 'api/spots_api.dart';

enum CamperRouteType { eco, fast, scenic }

class NavigationOptionsScreen extends StatefulWidget {
  final SpotDto spot;

  const NavigationOptionsScreen({super.key, required this.spot});

  @override
  State<NavigationOptionsScreen> createState() => _NavigationOptionsScreenState();
}

class _NavigationOptionsScreenState extends State<NavigationOptionsScreen> {
  CamperRouteType? _selected;
  MapboxMapController? _previewMap;

  void _onMapCreated(MapboxMapController map) async {
    _previewMap = map;
    
    // Aggiungiamo il marker sulla destinazione
    await _previewMap!.addSymbol(
      SymbolOptions(
        geometry: LatLng(widget.spot.latitude, widget.spot.longitude),
        iconImage: 'assets/icons/icon_p.png', // Usa l'icona standard dei POI o una specifica
        iconSize: 1.5,
      ),
    );

    await _previewMap!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(widget.spot.latitude, widget.spot.longitude),
          zoom: 11,
        ),
      ),
    );
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
                child: MapboxMap(
                  key: const ValueKey('navigation_preview_map'),
                  accessToken: mapboxAccessToken,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      widget.spot.latitude,
                      widget.spot.longitude,
                    ),
                    zoom: 11,
                  ),
                  styleString: MapboxStyles.MAPBOX_STREETS,
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
                    debugPrint(
                        'START NAVIGATION to ${widget.spot.name} with $_selected');
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
      onTap: () => setState(() => _selected = type),
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