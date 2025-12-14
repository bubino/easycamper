import 'package:flutter/material.dart';

class SpotReviewsScreen extends StatelessWidget {
  final String spotName;

  const SpotReviewsScreen({super.key, required this.spotName});

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF071814);
    const cardBg = Color(0xFF0d221a);

    final title = spotName.isNotEmpty ? 'Recensioni • $spotName' : 'Recensioni spot';

    // Mock di qualche recensione fittizia
    final mockReviews = [
      _Review(
        author: 'Marco R.',
        rating: 5,
        text:
            'Area molto tranquilla, servizi puliti e personale gentile. Perfetta per visitare il centro.',
        date: '2 giorni fa',
      ),
      _Review(
        author: 'Laura S.',
        rating: 4,
        text: 'Piazzole spaziose, un po\' rumorosa la sera ma nel complesso ottima.',
        date: '1 settimana fa',
      ),
      _Review(
        author: 'Stefano B.',
        rating: 3,
        text:
            'Servizi ok ma sarebbe utile avere più prese elettriche. Comoda la posizione.',
        date: '3 settimane fa',
      ),
    ];

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final r = mockReviews[index];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF123426)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      r.author,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < r.rating ? Icons.star : Icons.star_border,
                          size: 14,
                          color: Colors.amber,
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  r.date,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  r.text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: mockReviews.length,
      ),
    );
  }
}

class _Review {
  final String author;
  final int rating;
  final String text;
  final String date;

  const _Review({
    required this.author,
    required this.rating,
    required this.text,
    required this.date,
  });
}
