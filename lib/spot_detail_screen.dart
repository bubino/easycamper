import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/spot_dto.dart';
import 'api/spots_api.dart';
import 'storage/favorites_storage.dart' show favoritesProvider;
import 'spot_reviews_screen.dart';
import 'navigation_options_screen.dart';
import 'add_spot_screen.dart' show serviceIconWidgetForLabel;
import 'api/auth_state.dart';

class SpotDetailScreen extends ConsumerWidget {
  final SpotDto spot;

  const SpotDetailScreen({super.key, required this.spot});

  bool _isLikelyOwnedSpot(WidgetRef ref, SpotDto spot) {
    final sessionUserId = ref.read(authControllerProvider).value?.session?.userId;
    if (sessionUserId == null || sessionUserId.isEmpty) return false;
    final ownerId = spot.userId;
    if (ownerId == null || ownerId.isEmpty) return false;
    return ownerId == sessionUserId;
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    const danger = Color(0xFFd32f2f);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0d221a),
          title: const Text('Eliminare lo spot?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Questa azione non è reversibile.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: danger),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      final api = ref.read(spotsApiClientProvider);
      await api.deleteSpot(spot.id);
      if (!context.mounted) return;
      // Torna indietro e segnala che c'è stato un cambio
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spot eliminato.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile eliminare lo spot: $e')),
      );
    }
  }

  Future<void> _openEdit(BuildContext context, WidgetRef ref) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditSpotScreen(initialSpot: spot),
      ),
    );

    if (updated == true && context.mounted) {
      // Ricarichiamo il dettaglio spot in caso il backend abbia aggiornato rating/services ecc.
      try {
        final api = ref.read(spotsApiClientProvider);
        final refreshed = await api.fetchSpotById(spot.id);
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SpotDetailScreen(spot: refreshed),
          ),
        );
      } catch (_) {
        // ignore
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const darkBg = Color(0xFF071814);
    const primary = Color(0xFF1b7f6b);

    final favoriteIds = ref.watch(favoritesProvider);
    final isFav = favoriteIds.contains(spot.id);

    final canManage = _isLikelyOwnedSpot(ref, spot);

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
                              if (canManage)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                                  color: const Color(0xFF0d221a),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openEdit(context, ref);
                                    } else if (value == 'delete') {
                                      _confirmAndDelete(context, ref);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Modifica', style: TextStyle(color: Colors.white)),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Elimina', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
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

class EditSpotScreen extends ConsumerStatefulWidget {
  final SpotDto initialSpot;

  const EditSpotScreen({super.key, required this.initialSpot});

  @override
  ConsumerState<EditSpotScreen> createState() => _EditSpotScreenState();
}

class _EditSpotScreenState extends ConsumerState<EditSpotScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  bool _saving = false;

  // Minimal fields (keep UX small): name + description only for now.
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialSpot.name);
    _descriptionController =
        TextEditingController(text: widget.initialSpot.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(spotsApiClientProvider);
      await api.updateSpot(
        widget.initialSpot.id,
        SpotUpdateDto(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spot aggiornato.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile salvare: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF071814);
    const primary = Color(0xFF1b7f6b);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        title: const Text('Modifica spot'),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Nome spot',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primary),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Inserisci un nome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Descrizione',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Salva'),
                  ),
                ),
              ],
            ),
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

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const Text(
        'Nessun servizio disponibile',
        style: TextStyle(color: Colors.white70, fontSize: 13),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: services.map((label) {
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
              // PNG icons consistent with AddSpotScreen
              serviceIconWidgetForLabel(label, size: 14),
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