import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SpotReviewsScreen extends StatefulWidget {
  final String spotName;

  const SpotReviewsScreen({super.key, required this.spotName});

  @override
  State<SpotReviewsScreen> createState() => _SpotReviewsScreenState();
}

class _SpotReviewsScreenState extends State<SpotReviewsScreen> {
  final List<_Review> _reviews = [
    const _Review(
      author: 'Marco R.',
      rating: 5,
      text:
          'Area molto tranquilla, servizi puliti e personale gentile. Perfetta per visitare il centro.',
      date: '2 giorni fa',
    ),
    const _Review(
      author: 'Laura S.',
      rating: 4,
      text: 'Piazzole spaziose, un po\' rumorosa la sera ma nel complesso ottima.',
      date: '1 settimana fa',
    ),
    const _Review(
      author: 'Stefano B.',
      rating: 3,
      text:
          'Servizi ok ma sarebbe utile avere più prese elettriche. Comoda la posizione.',
      date: '3 settimane fa',
    ),
  ];

  Future<void> _openAddReviewDialog() async {
    final result = await showModalBottomSheet<_Review>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071814),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _AddReviewSheet(),
    );

    if (result != null) {
      setState(() {
        _reviews.insert(0, result);
      });
    }
  }

  void _openPhotoViewer({
    required List<String> photoPaths,
    required int initialIndex,
  }) {
    if (photoPaths.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) => _PhotoViewerDialog(
        photoPaths: photoPaths,
        initialIndex: initialIndex,
      ),
    );
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
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Aggiungi recensione',
            onPressed: _openAddReviewDialog,
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final r = _reviews[index];
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
                if (r.photoPaths.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: r.photoPaths.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final file = File(r.photoPaths[i]);
                        return GestureDetector(
                          onTap: () => _openPhotoViewer(
                            photoPaths: r.photoPaths,
                            initialIndex: i,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              file,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
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

class _Review {
  final String author;
  final int rating;
  final String text;
  final String date;
  final List<String> photoPaths;

  const _Review({
    required this.author,
    required this.rating,
    required this.text,
    required this.date,
    this.photoPaths = const [],
  });
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
  final List<XFile> _photos = [];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    try {
      final files = await picker.pickMultiImage();
      if (files.isEmpty) return;
      setState(() {
        // massimo 2 foto
        final remaining = 2 - _photos.length;
        if (remaining <= 0) return;
        _photos.addAll(files.take(remaining));
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante la selezione delle foto.')),
      );
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final review = _Review(
      author: 'Utente', // mock, in futuro useremo il profilo reale
      rating: _rating,
      text: _textCtrl.text.trim(),
      date: 'Adesso',
      photoPaths: _photos.map((p) => p.path).toList(),
    );

    Navigator.of(context).pop<_Review>(review);
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          _photos.length >= 2 ? null : _pickPhotos,
                      icon: const Icon(Icons.add_a_photo, size: 18),
                      label: const Text('Aggiungi foto'),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _photos.isEmpty
                          ? 'Max 2 foto'
                          : '${_photos.length} / 2 foto',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_photos.isNotEmpty)
                  SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_photos[i].path),
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
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

class _PhotoViewerDialog extends StatefulWidget {
  final List<String> photoPaths;
  final int initialIndex;

  const _PhotoViewerDialog({
    required this.photoPaths,
    required this.initialIndex,
  });

  @override
  State<_PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<_PhotoViewerDialog> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photoPaths.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photoPaths.length;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: total,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final path = widget.photoPaths[i];
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Center(
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Chiudi',
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_index + 1} / $total',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
