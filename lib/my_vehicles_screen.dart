import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/vehicle_state.dart';
import 'vehicle_form_screen.dart';

class MyVehiclesScreen extends ConsumerWidget {
  const MyVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const darkBg = Color(0xFF071814);
    final vehicles = ref.watch(vehiclesProvider);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'I miei veicoli',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (vehicles.isEmpty)
                const Text(
                  'Non hai ancora aggiunto alcun veicolo.',
                  style: TextStyle(color: Colors.white70),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final v = vehicles[index];
                      return _VehicleCard(vehicle: v);
                    },
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (vehicles.length >= VehiclesNotifier.maxVehicles) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Puoi salvare al massimo 2 veicoli'),
                        ),
                      );
                      return;
                    }
                    // Per ora andiamo direttamente al form manuale; la schermata di scelta metodo arriverà dopo
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VehicleFormScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi veicolo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleCard extends ConsumerStatefulWidget {
  final Vehicle vehicle;
  const _VehicleCard({required this.vehicle});

  @override
  ConsumerState<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends ConsumerState<_VehicleCard> {
  static const _prefsPrefix = 'vehicle_image_path_v1:';

  bool _loading = true;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadImagePath();
  }

  Future<void> _loadImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('$_prefsPrefix${widget.vehicle.id}');

    if (!mounted) return;
    setState(() {
      _imagePath = (path != null && path.trim().isNotEmpty) ? path.trim() : null;
      _loading = false;
    });

    // Se il provider non ha ancora l'immagine, aggiorniamo lo state in memoria.
    if (_imagePath != null && widget.vehicle.imagePath != _imagePath) {
      ref
          .read(vehiclesProvider.notifier)
          .updateVehicle(widget.vehicle.copyWith(imagePath: _imagePath));
    }
  }

  Future<void> _setImagePath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsPrefix${widget.vehicle.id}';

    if (path == null) {
      await prefs.remove(key);
      ref
          .read(vehiclesProvider.notifier)
          .updateVehicle(widget.vehicle.copyWith(clearImagePath: true));
    } else {
      await prefs.setString(key, path);
      ref
          .read(vehiclesProvider.notifier)
          .updateVehicle(widget.vehicle.copyWith(imagePath: path));
    }

    if (!mounted) return;
    setState(() => _imagePath = path);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;
      await _setImagePath(picked.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore selezione immagine: $e')),
      );
    }
  }

  Future<void> _removeImage() async {
    await _setImagePath(null);
  }

  Future<void> _deleteVehicle() async {
    // Rimuove prima l'immagine associata (se presente) per evitare preferenze orfane.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefsPrefix${widget.vehicle.id}');
    } catch (_) {
      // ignore: se fallisce la pulizia prefs, eliminiamo comunque il veicolo
    }

    ref.read(vehiclesProvider.notifier).removeVehicle(widget.vehicle.id);
  }

  @override
  Widget build(BuildContext context) {
    const tileBg = Color(0xFF0d221a);

    final v = widget.vehicle;

    ImageProvider? img;
    final path = _imagePath ?? v.imagePath;
    if (path != null && File(path).existsSync()) {
      img = FileImage(File(path));
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF123426)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF1b7f6b),
          backgroundImage: img,
          child: img == null
              ? const Icon(Icons.directions_bus, color: Colors.white)
              : null,
        ),
        title: Text(
          '${v.brand} ${v.model} (${v.year})',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Lunghezza: ${v.lengthMeters.toStringAsFixed(2)} m, '
          'Altezza: ${v.heightMeters.toStringAsFixed(2)} m, '
          'Larghezza: ${v.widthMeters.toStringAsFixed(2)} m, '
          'Peso: ${v.weightKg.toStringAsFixed(0)} kg',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              tooltip: 'Immagine veicolo',
              onSelected: (value) async {
                switch (value) {
                  case 'pick':
                    await _pickImage();
                    break;
                  case 'remove':
                    await _removeImage();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'pick',
                  child: Text('Aggiungi / Cambia immagine'),
                ),
                PopupMenuItem(
                  value: 'remove',
                  enabled: path != null,
                  child: const Text('Rimuovi immagine'),
                ),
              ],
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_outlined, color: Colors.white70),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VehicleFormScreen(existing: v),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _deleteVehicle,
            ),
          ],
        ),
      ),
    );
  }
}
