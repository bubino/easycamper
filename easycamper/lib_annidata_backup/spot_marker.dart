import 'package:flutter/material.dart';
import 'api/spots_api.dart';
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
      case 'Area Sosta':
        return Color(0xFF1b7f6b);
      case 'Campeggio':
        return Color(0xFF2e5fa5);
      case 'Carico Acqua':
        return Color(0xFF4fc3f7);
      case 'Scarico':
        return Color(0xFF8e24aa);
      case 'Elettricità':
        return Color(0xFFffd600);
      case 'Pet Friendly':
        return Color(0xFFff7043);
      case 'Vista Panoramica':
        return Color(0xFF00bcd4);
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final dto = SpotDto(
          id: spot.id,
          name: spot.name,
          description: spot.shortDescription ?? '',
          latitude: spot.latitude,
          longitude: spot.longitude,
          type: spot.type,
          services: spot.services,
          rating: spot.rating ?? 0,
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
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Column(
          children: [
            Icon(
              isFavorite ? Icons.favorite : Icons.place,
              color: getTypeColor(),
              size: 28,
            ),
            Text(spot.name,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
