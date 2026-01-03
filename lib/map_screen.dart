import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'api/spots_api.dart';
import 'profile_screen.dart';
import 'spot_detail_screen.dart';
import 'add_spot_screen.dart';
import 'easycamper_map.dart';
import 'saved_spots_screen.dart';
import 'spot_search_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final SpotsApiClient _spotsApiClient;
  final GlobalKey<EasyCamperMapState> _mapKey = GlobalKey<EasyCamperMapState>();

  Map<String, dynamic> _activeFilters = {};
  bool _isLoading = false;
  SpotMarkerData? _selectedSpot;
  List<SpotMarkerData> _lastSpots = const [];

  bool get _isMobile => defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _spotsApiClient = ref.read(spotsApiClientProvider);
  }

  Future<void> _centerOnUser() async {
    if (!_isMobile) return;
    try {
      final position = await Geolocator.getCurrentPosition();
      await _mapKey.currentState?.centerOn(position.latitude, position.longitude, zoom: 12);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile ottenere la posizione. Controlla i permessi.')),
      );
    }
  }

  List<IconData> _pickServiceIcons(List<String> services) {
    final icons = <IconData>[];
    bool has(String label) => services.contains(label);

    if (has('Elettricità')) icons.add(Icons.bolt);
    if (has('Acqua')) icons.add(Icons.water_drop);
    if (has('Wi‑Fi')) icons.add(Icons.wifi);
    if (has('Animali ammessi')) icons.add(Icons.pets);
    if (has('Ristorante')) icons.add(Icons.restaurant);
    if (has('Piscina')) icons.add(Icons.pool);

    return icons.take(3).toList();
  }

  String _mapTipoAreaReadable(String? backendType) {
    switch (backendType) {
      case 'area_sosta':
        return 'Area di sosta';
      case 'campeggio':
        return 'Campeggio';
      case 'agricampeggio':
        return 'Agricampeggio';
      default:
        return 'Area camper';
    }
  }

  SpotFilters _buildFilters() {
    final tipiArea = (_activeFilters['tipiArea'] as Map<String, bool>?) ?? {};
    final servizi = (_activeFilters['servizi'] as Map<String, bool>?) ?? {};
    final minRating = _activeFilters['minRating'] as double?;

    final types = tipiArea.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final services = servizi.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    return SpotFilters(
      types: types,
      services: services,
      minRating: minRating,
    );
  }

  void _onSpotsChanged(List<SpotMarkerData> spots) {
    _lastSpots = spots;
  }

  void _onBottomNavTap(int index) async {
    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SavedSpotsScreen(),
        ),
      );
      return;
    }
    if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        ),
      );
      return;
    }
    if (index == 1) {
      final selected = await Navigator.of(context).push<SpotMarkerData>(
        MaterialPageRoute(
          builder: (_) => SpotSearchScreen(
            initialSpots: _lastSpots,
            spotsApiClient: _spotsApiClient,
          ),
        ),
      );
      if (selected != null) {
        await _mapKey.currentState?.centerOn(
          selected.latitude,
          selected.longitude,
          zoom: 13,
        );
      }
      return;
    }
  }

  void _openSpotDetailsFromMarker(SpotMarkerData spot) async {
    try {
      final api = ref.read(spotsApiClientProvider);
      final detail = await api.fetchSpotById(spot.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SpotDetailScreen(spot: detail),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile caricare i dettagli dello spot: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF071814);
    const primary = Color(0xFF1b7f6b);
    const accentText = Color(0xFFd6f1e5);

    return Scaffold(
      backgroundColor: darkBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: EasyCamperMap(
              key: _mapKey,
              spotsApiClient: _spotsApiClient,
              isMobile: _isMobile,
              filtersBuilder: _buildFilters,
              onSpotsChanged: _onSpotsChanged,
              onSpotSelected: (spot) {
                setState(() => _selectedSpot = spot);
              },
              onLoadingChanged: (loading) {
                setState(() => _isLoading = loading);
              },
            ),
          ),
          if (_isLoading)
            const Positioned(
              top: 32,
              right: 16,
              child: CircularProgressIndicator(),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: _centerOnUser,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0d221a),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: accentText,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 6,
                  ),
                  onPressed: () async {
                    final created = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const AddSpotScreen(),
                      ),
                    );
                    if (created == true) {
                      _mapKey.currentState?.reload();
                    }
                  },
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text('Aggiungi spot'),
                ),
              ],
            ),
          ),
          if (_selectedSpot != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 56 + 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SpotCard(
                  spot: _selectedSpot!,
                  tipoAreaReadable: _mapTipoAreaReadable(_selectedSpot!.type),
                  serviceIcons: _pickServiceIcons(_selectedSpot!.services),
                  onClose: () => setState(() => _selectedSpot = null),
                  onDetails: () {
                    _openSpotDetailsFromMarker(_selectedSpot!);
                  },
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: darkBg,
        selectedItemColor: primary,
        unselectedItemColor: accentText,
        currentIndex: 0,
        onTap: _onBottomNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mappa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Ricerca',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Preferiti',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profilo',
          ),
        ],
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  final SpotMarkerData spot;
  final String tipoAreaReadable;
  final List<IconData> serviceIcons;
  final VoidCallback onClose;
  final VoidCallback onDetails;

  const _SpotCard({
    required this.spot,
    required this.tipoAreaReadable,
    required this.serviceIcons,
    required this.onClose,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0d221a);
    const accentText = Color(0xFFd6f1e5);
    final previewUrl = spot.photos.isNotEmpty ? spot.photos.first : null;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: previewUrl == null
                  ? const Icon(Icons.photo, color: Colors.white54, size: 18)
                  : Image.network(
                      previewUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.photo, color: Colors.white54, size: 18),
                    ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.place, color: accentText, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        tipoAreaReadable,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      if (spot.rating != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star,
                            size: 12, color: Colors.amberAccent),
                        const SizedBox(width: 2),
                        Text(
                          spot.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (spot.shortDescription != null &&
                      spot.shortDescription!.trim().isNotEmpty)
                    Text(
                      spot.shortDescription!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: spot.services
                        .take(3)
                        .map((label) => Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: serviceIconWidgetForLabel(label, size: 16),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 18),
              onPressed: onClose,
            ),
            TextButton(
              onPressed: onDetails,
              child: const Text(
                'Dettagli',
                style: TextStyle(color: accentText, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
