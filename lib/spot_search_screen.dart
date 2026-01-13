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

  String _normalizeService(String input) {
    var s = input.trim().toLowerCase();

    // Replace common separators with spaces.
    s = s.replaceAll(RegExp(r'[_\-]+'), ' ');

    // Best-effort remove most common accents we may see in Italian/French labels.
    s = s
        .replaceAll('à', 'a')
        .replaceAll('á', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('í', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('ú', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');

    // Collapse whitespace.
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  bool _hasAnyToken(String haystack, List<String> tokens) {
    for (final t in tokens) {
      if (haystack.contains(t)) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _filtered = widget.initialSpots;
    _controller.addListener(_apply);

    assert(() {
      // Debug-only: quickly see which service keys we get from backend/mock.
      final set = <String>{};
      for (final s in widget.initialSpots) {
        for (final srv in s.services) {
          set.add(_normalizeService(srv));
        }
      }
      // ignore: avoid_print
      print('SPOT SEARCH DEBUG: service keys seen (${set.length}): ${set.toList()..sort()}');
      return true;
    }());
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

  String _typeLabel(String? type) {
    switch (type) {
      case 'campeggio':
        return 'Campeggio';
      case 'agricampeggio':
        return 'Agricampeggio';
      case 'area_sosta':
        return 'Area sosta';
      case 'scarico':
        return 'Scarico';
      case 'carico_acqua':
        return 'Carico acqua';
      default:
        return 'Area sosta';
    }
  }

  String _typeAsset(String? type) {
    switch (type) {
      case 'campeggio':
        return 'assets/icons/markers/icon_c.png';
      case 'agricampeggio':
        return 'assets/icons/markers/icon_ar.png';
      case 'area_sosta':
        return 'assets/icons/markers/icon_p.png';
      case 'scarico':
        // riuso icona servizio (stile coerente con i servizi)
        return 'assets/icons/markers/service_eau_noire.png';
      case 'carico_acqua':
        return 'assets/icons/markers/service_point_eau.png';
      default:
        return 'assets/icons/markers/icon_p.png';
    }
  }

  String? _serviceAsset(String service) {
    final s = _normalizeService(service);

    // Exact matches (normalized) including backend keys seen in logs.
    switch (s) {
      case 'wifi':
      case 'service wifi':
        return 'assets/icons/markers/service_wifi.png';

      case 'electricity':
      case 'elettricita':
      case 'elettricità':
      case 'corrente':
      case '220v':
        return 'assets/icons/markers/service_electricite.png';

      case 'water':
      case 'acqua':
      case 'carico acqua':
      case 'punto acqua':
      case 'point eau':
        return 'assets/icons/markers/service_point_eau.png';

      case 'shower':
      case 'showers':
      case 'doccia':
      case 'douche':
        return 'assets/icons/markers/service_douche.png';

      case 'toilet public':
      case 'toilette':
      case 'wc':
      case 'bagno':
      case 'toilets':
        return 'assets/icons/markers/service_wc_public.png';

      case 'trash':
      case 'poubelle':
      case 'rifiuti':
      case 'spazzatura':
        return 'assets/icons/markers/service_poubelle.png';

      default:
        break;
    }

    // Keyword fallbacks
    if (_hasAnyToken(s, ['electric', 'elettric', 'corrente', '220v', 'power'])) {
      return 'assets/icons/markers/service_electricite.png';
    }

    if (_hasAnyToken(s, ['water', 'acqua', 'potabile', 'drinking', 'point eau', 'punto acqua', 'carico'])) {
      if (!_hasAnyToken(s, ['scarico', 'dump', 'waste', 'grey', 'gray', 'black', 'eau usee', 'eau noire'])) {
        return 'assets/icons/markers/service_point_eau.png';
      }
    }

    if (_hasAnyToken(s, ['shower', 'showers', 'doccia', 'douche'])) {
      return 'assets/icons/markers/service_douche.png';
    }

    if (_hasAnyToken(s, ['toilet', 'toilette', 'wc', 'bagno'])) {
      return 'assets/icons/markers/service_wc_public.png';
    }

    if (_hasAnyToken(s, ['grey', 'gray', 'grig', 'waste', 'used', 'usee', 'eau usee', 'scarico', 'dump', 'cassette', 'cassetta', 'carico scarico'])) {
      if (_hasAnyToken(s, ['black', 'nere', 'noire', 'eau noire'])) {
        return 'assets/icons/markers/service_eau_noire.png';
      }
      return 'assets/icons/markers/service_eau_usee.png';
    }

    if (_hasAnyToken(s, ['black', 'nere', 'noire', 'eau noire'])) {
      return 'assets/icons/markers/service_eau_noire.png';
    }

    if (_hasAnyToken(s, ['pet', 'cani', 'dog', 'animaux', 'animals'])) {
      return 'assets/icons/markers/service_animaux.png';
    }

    if (_hasAnyToken(s, ['trash', 'poubelle', 'rifiuti', 'spazz', 'waste bin'])) {
      return 'assets/icons/markers/service_poubelle.png';
    }

    return null;
  }

  List<Widget> _buildServiceIcons(List<String> services) {
    final assets = <String>[];
    for (final srv in services) {
      final asset = _serviceAsset(srv);
      if (asset != null && !assets.contains(asset)) {
        assets.add(asset);
      }
      if (assets.length >= 4) break;
    }

    Widget img(String asset) => Image.asset(
          asset,
          width: 16,
          height: 16,
          // Avoid tinting (some PNGs are already colored and look like grey boxes when tinted).
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(width: 16, height: 16),
        );

    return assets
        .map(
          (asset) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: img(asset),
          ),
        )
        .toList();
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
                      final services = s.services;

                      return ListTile(
                        leading: Image.asset(
                          _typeAsset(s.type),
                          width: 28,
                          height: 28,
                        ),
                        title: Text(
                          s.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (s.shortDescription != null &&
                                s.shortDescription!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  s.shortDescription!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF123426),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFF1b7f6b)
                                          .withOpacity(0.35),
                                    ),
                                  ),
                                  child: Text(
                                    _typeLabel(s.type),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ..._buildServiceIcons(services),
                              ],
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () =>
                            Navigator.of(context).pop<SpotMarkerData>(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
