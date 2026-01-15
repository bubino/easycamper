import 'package:flutter/material.dart';

import 'api/spots_api.dart';
import 'api/spot_dto.dart';
import 'spot_detail_screen.dart';

class SpotMarker extends StatelessWidget {
  final SpotMarkerData spot;
  final bool isFavorite;
  final VoidCallback? onTap;

  const SpotMarker({
    super.key,
    required this.spot,
    this.isFavorite = false,
    this.onTap,
  });

  Color getTypeColor() {
    switch (spot.type) {
      case 'area_sosta':
        return const Color(0xFF1b7f6b);
      case 'campeggio':
        return const Color(0xFF2e5fa5);
      case 'agricampeggio':
        return const Color(0xFF4fc3f7);
      case 'scarico':
        return const Color(0xFFb23a3a);
      case 'carico_acqua':
        return const Color(0xFF2aa7c9);
      default:
        return Colors.blueGrey;
    }
  }

  IconData _iconForType() {
    switch (spot.type) {
      case 'scarico':
        return Icons.delete_outline;
      case 'carico_acqua':
        return Icons.water_drop;
      default:
        return isFavorite ? Icons.favorite : Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ??
          () {
            final dto = SpotDto(
              id: spot.id,
              name: spot.name,
              description: spot.shortDescription ?? '',
              lat: spot.latitude,
              lng: spot.longitude,
              type: spot.type ?? 'area_sosta',
              services: spot.services,
              rating: spot.rating ?? 0,
              // FIX: passa le foto dal marker, altrimenti nel dettaglio non si vedrà nulla
              photos: spot.photos,
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SpotDetailScreen(spot: dto),
              ),
            );
          },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Column(
          children: [
            Icon(
              _iconForType(),
              color: getTypeColor(),
              size: 28,
            ),
            Text(
              spot.name,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
