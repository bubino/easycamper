import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/spot_dto.dart';
import 'storage/favorites_storage.dart' show favoritesProvider;
import 'spot_reviews_screen.dart';
import 'navigation_options_screen.dart';

class SpotDetailScreen extends ConsumerWidget {
  final SpotDto spot;

  const SpotDetailScreen({super.key, required this.spot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const darkBg = Color(0xFF071814);
    const primary = Color(0xFF1b7f6b);

    final favoriteIds = ref.watch(favoritesProvider);
    final isFav = favoriteIds.contains(spot.id);

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SpotHeroImage(spot: spot),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      color: darkBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  spot.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  ref
                                      .read(favoritesProvider.notifier)
                                      .toggle(spot.id);
                                },
                                icon: Icon(
                                  isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFav
                                      ? Colors.redAccent
                                      : Colors.white70,
                                ),
                                tooltip: isFav
                                    ? 'Rimuovi dai preferiti'
                                    : 'Aggiungi ai preferiti',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            spot.description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Servizi disponibili',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _AmenitiesGrid(services: spot.services),
                          const SizedBox(height: 24),
                          const Text(
                            'Recensioni',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ReviewsSection(
                            rating: spot.rating,
                            spotName: spot.name,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PositionedBackButton(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white, // testo bianco
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NavigationOptionsScreen(spot: spot),
                ),
              );
            },
            child: const Text('Vai'),
          ),
        ),
      ),
    );
  }
}

class PositionedBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xAA000000), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: CircleAvatar(
          backgroundColor: Colors.black54,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }
}

class _SpotHeroImage extends StatelessWidget {
  final SpotDto spot;

  const _SpotHeroImage({required this.spot});

  @override
  Widget build(BuildContext context) {
    final photo = spot.photos.isNotEmpty ? spot.photos.first : null;
    const placeholder = Icon(
      Icons.landscape,
      color: Colors.white54,
      size: 48,
    );

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF0d221a)),
          if (photo == null)
            const Center(child: placeholder)
          else
            Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(child: placeholder),
            ),
        ],
      ),
    );
  }
}

class _AmenitiesGrid extends StatelessWidget {
  final List<String> services;

  const _AmenitiesGrid({required this.services});

  IconData _iconForService(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('elettricit')) return Icons.bolt;
    if (lower.contains('acqua')) return Icons.water_drop;
    if (lower.contains('wi')) return Icons.wifi;
    if (lower.contains('animali')) return Icons.pets;
    if (lower.contains('wc') || lower.contains('bagni')) return Icons.wc;
    if (lower.contains('docce')) return Icons.shower;
    if (lower.contains('ristorante') || lower.contains('bar')) {
      return Icons.restaurant;
    }
    if (lower.contains('lavanderia')) return Icons.local_laundry_service;
    if (lower.contains('parco') || lower.contains('gioco')) {
      return Icons.park;
    }
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final items = services.isEmpty
        ? <String>['Elettricità', 'Acqua', 'Wi‑Fi', 'Animali ammessi']
        : services;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((label) {
        final icon = _iconForService(label);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0d221a),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1b7f6b), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF1b7f6b)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final double rating;
  final String spotName;

  const _ReviewsSection({
    required this.rating,
    required this.spotName,
  });

  @override
  Widget build(BuildContext context) {
    const barBg = Color(0xFF0d221a);
    const barFill = Color(0xFF4caf50);

    final displayRating = rating > 0 ? rating.toStringAsFixed(1) : '--';

    Widget buildBar(String label, double fraction, String percent) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: barBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: barFill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              percent,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayRating,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (index) {
                    final filled = rating >= index + 1;
                    return Icon(
                      Icons.star,
                      size: 16,
                      color: filled ? Colors.greenAccent : Colors.white24,
                    );
                  }),
                ),
                const SizedBox(height: 6),
                const Text(
                  '124 recensioni',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: [
                  buildBar('5', 0.6, '50%'),
                  const SizedBox(height: 6),
                  buildBar('4', 0.3, '30%'),
                  const SizedBox(height: 6),
                  buildBar('3', 0.1, '10%'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SpotReviewsScreen(spotName: spotName),
                ),
              );
            },
            child: const Text('Vedi tutte le recensioni'),
          ),
        ),
      ],
    );
  }
}