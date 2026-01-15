import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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
        photos: result.photos,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile pubblicare la recensione: $e')),
      );
    }
  }

  void _openPhotoViewer({
    required List<String> photoUrls,
    required int initialIndex,
  }) {
    if (photoUrls.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) => _PhotoViewerDialog(
        photoUrls: photoUrls,
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
                      if (r.photos.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 86,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: r.photos.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final url = r.photos[i];
                              return GestureDetector(
                                onTap: () => _openPhotoViewer(
                                  photoUrls: r.photos,
                                  initialIndex: i,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    url,
                                    width: 86,
                                    height: 86,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 86,
                                      height: 86,
                                      color: const Color(0xFF0d221a),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.broken_image, color: Colors.white54),
                                    ),
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

class _ReviewDraft {
  final int rating;
  final String text;
  final List<String> photos;
  const _ReviewDraft({required this.rating, required this.text, this.photos = const []});
}

class _AddReviewSheet extends StatefulWidget {
  const _AddReviewSheet();

  @override
  State<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<_AddReviewSheet> {
  final _formKey = GlobalKey<FormState>();
  final _textCtrl = TextEditingController();
  final List<XFile> _photos = [];
  bool _uploading = false;
  int _rating = 5;

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

  Future<List<String>> _uploadSelectedPhotos() async {
    if (_photos.isEmpty) return const [];

    final spotId = context.findAncestorWidgetOfExactType<SpotReviewsScreen>()?.spotId;
    if (spotId == null || spotId.isEmpty) return const [];

    final container = ProviderScope.containerOf(context, listen: false);
    final api = container.read(spotsApiClientProvider);

    final urls = <String>[];
    for (final x in _photos) {
      final bytes = await File(x.path).readAsBytes();
      final presigned = await api.getSpotReviewPhotoUploadUrl(spotId);
      final key = presigned['key']?.toString();
      final uploadUrl = presigned['url']?.toString();
      if (key == null || uploadUrl == null) continue;

      // upload to R2
      await api.uploadBytesToPresignedUrl(uploadUrl, bytes: bytes);
      final pub = await api.createSpotReviewPhotoPublicUrl(spotId, key: key);
      final url = pub['url']?.toString();
      if (url != null && url.isNotEmpty) urls.add(url);
      if (urls.length >= 2) break;
    }

    return urls;
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _uploading = true);
    try {
      final uploadedUrls = await _uploadSelectedPhotos();
      final draft = _ReviewDraft(
        rating: _rating,
        text: _textCtrl.text.trim(),
        photos: uploadedUrls,
      );
      if (!mounted) return;
      Navigator.of(context).pop<_ReviewDraft>(draft);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore upload foto: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
                      onPressed: _uploading || _photos.length >= 2 ? null : _pickPhotos,
                      icon: const Icon(Icons.add_a_photo, size: 18),
                      label: const Text('Aggiungi foto'),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _photos.isEmpty ? 'Max 2 foto' : '${_photos.length} / 2 foto',
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
                      onPressed: _uploading ? null : () => Navigator.of(context).maybePop(),
                      child: const Text('Annulla'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _uploading ? null : _submit,
                      child: _uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Pubblica'),
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
  final List<String> photoUrls;
  final int initialIndex;

  const _PhotoViewerDialog({
    required this.photoUrls,
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
    _index = widget.initialIndex.clamp(0, widget.photoUrls.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photoUrls.length;

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
                final url = widget.photoUrls[i];
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Center(
                    child: Image.network(url, fit: BoxFit.contain),
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
