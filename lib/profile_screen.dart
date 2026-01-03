import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/auth_state.dart';
import 'personal_data_screen.dart';
import 'my_vehicles_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const darkBg = Color(0xFF071814);
    const accentText = Color(0xFFd6f1e5);

    final authState = ref.watch(authControllerProvider);
    final session = authState.when(
      data: (state) => state.session,
      loading: () => null,
      error: (_, __) => null,
    );

    final displayName = (session?.username != null && session!.username!.isNotEmpty)
        ? session.username!
        : 'Utente EasyCamper';
    final displayEmail = session?.email ?? 'Email non disponibile';

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        title: const Text(
          'My Account',
          style: TextStyle(color: accentText),
        ),
        iconTheme: const IconThemeData(color: accentText),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileHeader(
                displayName: displayName,
                displayEmail: displayEmail,
              ),
              const SizedBox(height: 24),
              const Text(
                'Account',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _ProfileTile(
                icon: Icons.person_outline,
                title: 'Dati personali',
                subtitle: 'Gestisci le tue informazioni di profilo',
                onTap: () {
                  final email = session?.email ?? '';
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PersonalDataScreen(
                        initialEmail: email,
                      ),
                    ),
                  );
                },
              ),
              _ProfileTile(
                icon: Icons.directions_car_outlined,
                title: 'I miei veicoli',
                subtitle: 'Gestisci camper e veicoli associati',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyVehiclesScreen(),
                    ),
                  );
                },
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) {
                      GoRouter.of(context).go('/');
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatefulWidget {
  final String displayName;
  final String displayEmail;

  const _ProfileHeader({
    required this.displayName,
    required this.displayEmail,
  });

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  static const _prefsKey = 'profile_avatar_path_v1';

  // Final approach: store a generated cropped avatar image path.
  static const _prefsKeyCropped = 'profile_avatar_cropped_path_v3';

  String? _avatarPath;
  String? _croppedAvatarPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefsKey);
    final cropped = prefs.getString(_prefsKeyCropped);

    if (!mounted) return;
    setState(() {
      _avatarPath = (path != null && path.trim().isNotEmpty) ? path.trim() : null;
      _croppedAvatarPath =
          (cropped != null && cropped.trim().isNotEmpty) ? cropped.trim() : null;
      _loading = false;
    });
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    try {
      final picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (picked == null) return;

      final result = await Navigator.of(context).push<_AvatarCropResult>(
        MaterialPageRoute(
          builder: (_) => _AvatarCropperScreen(imagePath: picked.path),
        ),
      );
      if (result == null) return;

      final croppedPath = await _generateAndPersistCroppedAvatar(
        originalPath: picked.path,
        cropRectInImagePx: result.cropRectInImagePx,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, picked.path);
      await prefs.setString(_prefsKeyCropped, croppedPath);

      if (!mounted) return;
      setState(() {
        _avatarPath = picked.path;
        _croppedAvatarPath = croppedPath;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore selezione avatar: $e')),
      );
    }
  }

  Future<String> _generateAndPersistCroppedAvatar({
    required String originalPath,
    required Rect cropRectInImagePx,
  }) async {
    // Decode original image
    final bytes = await File(originalPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final src = frame.image;

    // Clamp crop rect
    final safe = Rect.fromLTWH(
      cropRectInImagePx.left.clamp(0.0, src.width.toDouble()),
      cropRectInImagePx.top.clamp(0.0, src.height.toDouble()),
      cropRectInImagePx.width
          .clamp(1.0, src.width.toDouble() - cropRectInImagePx.left),
      cropRectInImagePx.height
          .clamp(1.0, src.height.toDouble() - cropRectInImagePx.top),
    );

    // Render to square 512x512
    const outSize = 512;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()..isAntiAlias = true;
    final dst = Rect.fromLTWH(0, 0, outSize.toDouble(), outSize.toDouble());
    canvas.drawImageRect(src, safe, dst, paint);

    final picture = recorder.endRecording();
    final outImage = await picture.toImage(outSize, outSize);
    final pngData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    final outBytes = pngData!.buffer.asUint8List();

    // Store in app documents directory
    final dir = await Directory.systemTemp.createTemp('easycamper_avatar_');
    final outFile = File('${dir.path}/avatar_512.png');
    await outFile.writeAsBytes(outBytes, flush: true);
    return outFile.path;
  }

  @override
  Widget build(BuildContext context) {
    final cropped = _croppedAvatarPath;
    final avatarProvider = (cropped != null)
        ? FileImage(File(cropped)) as ImageProvider
        : (_avatarPath != null ? FileImage(File(_avatarPath!)) as ImageProvider : null);

    return Row(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF1b7f6b),
                child: avatarProvider == null
                    ? const Icon(Icons.person, color: Colors.white, size: 30)
                    : ClipOval(
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Image(
                            image: avatarProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: InkWell(
                onTap: _pickAvatar,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0d221a),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.edit, size: 14, color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                widget.displayEmail,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarCropResult {
  const _AvatarCropResult({required this.cropRectInImagePx});

  final Rect cropRectInImagePx;
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const tileBg = Color(0xFF0d221a);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF123426)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _AvatarCropperScreen extends StatefulWidget {
  final String imagePath;

  const _AvatarCropperScreen({required this.imagePath});

  @override
  State<_AvatarCropperScreen> createState() => _AvatarCropperScreenState();
}

class _AvatarCropperScreenState extends State<_AvatarCropperScreen> {
  final TransformationController _controller = TransformationController();

  // Cache image dimensions
  ui.Image? _decoded;
  bool _decoding = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _decoded = frame.image;
    } finally {
      if (!mounted) return;
      setState(() {
        _decoding = false;
        _controller.value = Matrix4.identity()..scale(1.0);
      });
    }
  }

  Rect _computeCropRectInImagePx(double viewportSize) {
    final img = _decoded;
    if (img == null) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }

    // With BoxFit.cover the image is scaled so the viewport is fully covered.
    // We approximate cover scale based on viewport square.
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();

    final coverScale = (viewportSize / iw).clamp(0.0, double.infinity);
    final coverScaleH = (viewportSize / ih).clamp(0.0, double.infinity);
    final baseScale = coverScale > coverScaleH ? coverScale : coverScaleH;

    // Controller matrix includes user scale and translation in viewport logical pixels.
    final m = _controller.value;
    final userScale = (m.storage[0] + m.storage[5]) / 2.0;
    final dx = m.storage[12];
    final dy = m.storage[13];

    // Effective scale from image px -> viewport px
    final s = baseScale * userScale;

    // The viewport shows a square of size viewportSize.
    // Map viewport (0..viewportSize) back to image px.
    // Translation moves the child inside the viewport: positive dx means image moved right.
    // Convert so that image origin in viewport is (-dx, -dy).
    final leftPx = (-dx) / s;
    final topPx = (-dy) / s;
    final sizePx = viewportSize / s;

    // Enforce square crop
    return Rect.fromLTWH(leftPx, topPx, sizePx, sizePx);
  }

  @override
  void dispose() {
    _controller.dispose();
    _decoded?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF071814);
    const cardBg = Color(0xFF0d221a);
    const primary = Color(0xFF1b7f6b);

    final size = MediaQuery.of(context).size;
    final shortest = size.shortestSide;
    final cropSize = (shortest * 0.82).clamp(280.0, 420.0);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Centra avatar'),
        actions: [
          TextButton(
            onPressed: _decoding
                ? null
                : () {
                    final rect = _computeCropRectInImagePx(cropSize);
                    Navigator.of(context)
                        .pop(_AvatarCropResult(cropRectInImagePx: rect));
                  },
            child: const Text('Salva', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: cropSize,
              height: cropSize,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: primary),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: _controller,
                      minScale: 0.4,
                      maxScale: 8.0,
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(300),
                      clipBehavior: Clip.none,
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _AvatarCropOverlayPainter(
                          borderColor: Colors.white.withOpacity(0.35),
                          scrimColor: Colors.black.withOpacity(0.35),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Pizzica per zoomare, trascina per centrare.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarCropOverlayPainter extends CustomPainter {
  _AvatarCropOverlayPainter({required this.borderColor, required this.scrimColor});

  final Color borderColor;
  final Color scrimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 16;

    final circlePath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    final fullPath = Path()..addRect(rect);

    // Scrim outside circle
    final scrimPaint = Paint()
      ..color = scrimColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(Path.combine(PathOperation.difference, fullPath, circlePath), scrimPaint);

    // Circle border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _AvatarCropOverlayPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor || oldDelegate.scrimColor != scrimColor;
  }
}
