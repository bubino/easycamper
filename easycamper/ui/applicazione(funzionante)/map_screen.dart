import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'api/spots_api.dart';
import 'filters_panel.dart';
import 'api/auth_state.dart';
import 'profile_screen.dart';
import 'spot_detail_screen.dart';
import 'add_spot_screen.dart';
import 'easycamper_map.dart';
import 'saved_spots_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final SpotsApiClient _spotsApiClient;
  final GlobalKey<EasyCamperMapState> _mapKey = GlobalKey<EasyCamperMapState>();

  List<SpotMarkerData> _currentSpots = [];
  Map<String, dynamic> _activeFilters = {};
  bool _isLoading = false;
  SpotMarkerData? _selectedSpot;
  double? _lastKnownLat;
  double? _lastKnownLng;

  bool get _isMobile => defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  bool get _hasActiveFilters {
    final tipiArea = (_activeFilters['tipiArea'] as Map<String, bool>?) ?? {};
    final servizi = (_activeFilters['servizi'] as Map<String, bool>?) ?? {};
    final minRating = (_activeFilters['minRating'] as double?) ?? 0;

    final anyTipo = tipiArea.values.any((v) => v);
    final anyServizio = servizi.values.any((v) => v);
    return anyTipo || anyServizio || minRating > 0;
  }

  @override
  void initState() {
    super.initState();
    _spotsApiClient = ref.read(spotsApiClientProvider);
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (!_isMobile) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      _lastKnownLat = position.latitude;
      _lastKnownLng = position.longitude;
    });

    await _mapKey.currentState
        ?.centerOn(position.latitude, position.longitude, zoom: 12);
  }

  Future<void> _handleLogout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    context.go('/');
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

  Future<void> _navigateToSpotDetail(SpotMarkerData markerData) async {
    setState(() => _isLoading = true);
    try {
      final spotDto = await _spotsApiClient.fetchSpotById(markerData.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SpotDetailScreen(spot: spotDto),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile caricare i dettagli: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openFilters() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      builder: (ctx) {
        return _FiltersDialog(
          initialFilters: _activeFilters,
          onApplied: (filters) {
            setState(() {
              _activeFilters = filters;
            });
            _mapKey.currentState?.reload();
          },
        );
      },
    );
  }

  void _centerOnUser() async {
    if (!_isMobile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'La centratura automatica è disponibile solo su iOS/Android.'),
        ),
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _lastKnownLat = position.latitude;
        _lastKnownLng = position.longitude;
      });
      await _mapKey.currentState
          ?.centerOn(position.latitude, position.longitude, zoom: 12);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Impossibile ottenere la posizione. Controlla i permessi GPS.'),
        ),
      );
    }
  }

  void _openSpotDetail(Map<String, dynamic> rawSpot) {
    final spot = SpotDto.fromJson(rawSpot);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpotDetailScreen(spot: spot),
      ),
    );
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

  void _onBottomNavTap(int index) {
    if (index == 1) {
      // Ricerca: Apriamo una schermata di ricerca spot
      showSearch(
        context: context,
        delegate: SpotSearchDelegate(
          spots: _currentSpots,
          onSpotSelected: (spot) {
            _mapKey.currentState?.centerOn(spot.latitude, spot.longitude, zoom: 16);
            setState(() => _selectedSpot = spot);
          },
        ),
      );
      return;
    }
    if (index == 2) {
      // Preferiti: ora collegato correttamente
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sezione non ancora disponibile nella preview.'),
      ),
    );
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
              onSpotsChanged: (spots) {
                setState(() {
                  _currentSpots = spots;
                });
              },
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
          // Barra di ricerca rimossa come richiesto
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
                const SizedBox(width: 12),
                // New filter button
                InkWell(
                  onTap: _openFilters,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _hasActiveFilters ? primary : const Color(0xFF0d221a),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.tune,
                      color: _hasActiveFilters ? Colors.white : accentText,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
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
                    _navigateToSpotDetail(_selectedSpot!);
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
                    children: serviceIcons
                        .map((icon) => Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: Icon(icon,
                                  size: 14, color: Colors.white70),
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

class _FiltersDialog extends StatelessWidget {
  final Map<String, dynamic> initialFilters;
  final ValueChanged<Map<String, dynamic>> onApplied;

  const _FiltersDialog({
    required this.initialFilters,
    required this.onApplied,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPhone = size.width < 600;

    final maxWidth = isPhone ? size.width * 0.9 : 480.0;
    final maxHeight = isPhone ? size.height * 0.75 : size.height * 0.7;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: Material(
          color: Colors.transparent,
          child: FiltersPanel(
            // per ora ignoro initialFilters; potremo pre‑selezionare in futuro
            onFiltersChanged: (filters) {
              onApplied(filters);
              Navigator.of(context).maybePop();
            },
          ),
        ),
      ),
    );
  }
}

class SpotSearchDelegate extends SearchDelegate<SpotMarkerData?> {
  final List<SpotMarkerData> spots;
  final ValueChanged<SpotMarkerData> onSpotSelected;

  SpotSearchDelegate({required this.spots, required this.onSpotSelected});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    final filtered = spots.where((s) {
      return s.name.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final spot = filtered[index];
        return ListTile(
          title: Text(spot.name),
          subtitle: Text(spot.type ?? ''),
          onTap: () {
            onSpotSelected(spot);
            close(context, spot);
          },
        );
      },
    );
  }
}
