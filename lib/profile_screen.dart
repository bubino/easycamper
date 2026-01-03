import 'dart:io';

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
  static const _prefsKeyMatrix = 'profile_avatar_matrix_v1';

  String? _avatarPath;
  Matrix4? _avatarMatrix;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefsKey);
    final matrixRaw = prefs.getString(_prefsKeyMatrix);

    Matrix4? matrix;
    if (matrixRaw != null && matrixRaw.trim().isNotEmpty) {
      final parts = matrixRaw.split(',').map((e) => double.tryParse(e) ?? 0).toList();
      if (parts.length == 16) {
        matrix = Matrix4.fromList(parts);
      }
    }

    if (!mounted) return;
    setState(() {
      _avatarPath = (path != null && path.trim().isNotEmpty) ? path.trim() : null;
      _avatarMatrix = matrix;
      _loading = false;
    });
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      final matrix = await Navigator.of(context).push<Matrix4>(
        MaterialPageRoute(
          builder: (_) => _AvatarCropperScreen(imagePath: picked.path),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, picked.path);
      if (matrix != null) {
        await prefs.setString(
          _prefsKeyMatrix,
          matrix.storage.map((e) => e.toString()).join(','),
        );
      } else {
        await prefs.remove(_prefsKeyMatrix);
      }

      if (!mounted) return;
      setState(() {
        _avatarPath = picked.path;
        _avatarMatrix = matrix;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore selezione avatar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = (_avatarPath != null)
        ? FileImage(File(_avatarPath!)) as ImageProvider
        : null;

    final matrix = _avatarMatrix;

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
                          child: Transform(
                            transform: matrix ?? Matrix4.identity(),
                            child: Image.file(
                              File(_avatarPath!),
                              fit: BoxFit.cover,
                            ),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF071814);
    const cardBg = Color(0xFF0d221a);
    const primary = Color(0xFF1b7f6b);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Centra avatar'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_controller.value);
            },
            child: const Text('Salva', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Center(
        child: Container(
          width: 320,
          height: 320,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primary),
          ),
          clipBehavior: Clip.antiAlias,
          child: InteractiveViewer(
            transformationController: _controller,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
