import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/spots_api.dart';

class SpotReviewsScreen extends ConsumerStatefulWidget {
  final String spotId;
  final String spotName;

  const SpotReviewsScreen({super.key, required this.spotId, required this.spotName});

  @override
  ConsumerState<SpotReviewsScreen> createState() => _SpotReviewsScreenState();
}

class _SpotReviewsScreenState extends ConsumerState<SpotReviewsScreen> {
  bool _loading = true;
  List<SpotReviewDto> _reviews = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(spotsApiClientProvider);
      final items = await api.fetchSpotReviews(widget.spotId);
      if (!mounted) return;
      setState(() => _reviews = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore caricamento recensioni: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddReviewDialog() async {
    final result = await showModalBottomSheet<_ReviewDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071814),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _AddReviewSheet(),
    );

    if (result == null) return;

    try {
      final api = ref.read(spotsApiClientProvider);
      await api.upsertSpotReview(
        widget.spotId,
        rating: result.rating,
        comment: result.text,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile pubblicare la recensione: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF071814);
    const cardBg = Color(0xFF0d221a);

    final title = widget.spotName.isNotEmpty
        ? 'Recensioni • ${widget.spotName}'
        : 'Recensioni spot';

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Aggiungi recensione',
            onPressed: _openAddReviewDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final r = _reviews[index];
                final author = (r.username == null || r.username!.isEmpty) ? r.userId : r.username!;
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
                            author,
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
                      const SizedBox(height: 8),
                      if (r.comment != null && r.comment!.trim().isNotEmpty)
                        Text(
                          r.comment!,
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
              itemCount: _reviews.length,
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddReviewDialog,
        icon: const Icon(Icons.rate_review),
        label: const Text('Aggiungi'),
      ),
    );
  }
}

class _ReviewDraft {
  final int rating;
  final String text;
  const _ReviewDraft({required this.rating, required this.text});
}

class _AddReviewSheet extends StatefulWidget {
  const _AddReviewSheet();

  @override
  State<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<_AddReviewSheet> {
  final _formKey = GlobalKey<FormState>();
  final _textCtrl = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final draft = _ReviewDraft(
      rating: _rating,
      text: _textCtrl.text.trim(),
    );
    Navigator.of(context).pop<_ReviewDraft>(draft);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nuova recensione',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Valutazione',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (i) {
                    final starIndex = i + 1;
                    return IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        starIndex <= _rating
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                      ),
                      onPressed: () {
                        setState(() => _rating = starIndex);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _textCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'La tua esperienza',
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Color(0xFF0d221a),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Scrivi qualcosa sulla tua esperienza';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Annulla'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Pubblica'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
