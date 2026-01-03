import 'package:flutter/material.dart';

import 'api/spots_api.dart';

class SpotSearchScreen extends StatefulWidget {
  final SpotsApiClient spotsApiClient;
  final List<SpotMarkerData> initialSpots;

  const SpotSearchScreen({
    super.key,
    required this.spotsApiClient,
    required this.initialSpots,
  });

  @override
  State<SpotSearchScreen> createState() => _SpotSearchScreenState();
}

class _SpotSearchScreenState extends State<SpotSearchScreen> {
  final _controller = TextEditingController();

  List<SpotMarkerData> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.initialSpots;
    _controller.addListener(_apply);
  }

  @override
  void dispose() {
    _controller.removeListener(_apply);
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = widget.initialSpots);
      return;
    }

    setState(() {
      _filtered = widget.initialSpots
          .where((s) {
            final name = s.name.toLowerCase();
            final desc = (s.shortDescription ?? '').toLowerCase();
            return name.contains(q) || desc.contains(q);
          })
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF071814);
    const cardBg = Color(0xFF0d221a);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Ricerca'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cerca luoghi, aree sosta…',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: cardBg,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF123426)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF1b7f6b)),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Nessun risultato',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, index) {
                      final s = _filtered[index];
                      return ListTile(
                        leading: const Icon(Icons.place, color: Colors.white70),
                        title: Text(
                          s.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: (s.shortDescription != null && s.shortDescription!.trim().isNotEmpty)
                            ? Text(
                                s.shortDescription!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70),
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop<SpotMarkerData>(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
