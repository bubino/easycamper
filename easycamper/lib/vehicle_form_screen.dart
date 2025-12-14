import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/vehicle_state.dart';
import 'api/vehicle_models_api.dart';
import 'vehicle_model_search_screen.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  final Vehicle? existing;
  const VehicleFormScreen({super.key, this.existing});

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final v = widget.existing;
    _brandCtrl.text = v?.brand ?? '';
    _modelCtrl.text = v?.model ?? '';
    _yearCtrl.text = v?.year.toString() ?? '';
    _lengthCtrl.text = v?.lengthMeters.toString() ?? '';
    _heightCtrl.text = v?.heightMeters.toString() ?? '';
    _weightCtrl.text = v?.weightKg.toString() ?? '';
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _lengthCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF071814);
    const primary = Color(0xFF1b7f6b);
    final isEditing = widget.existing != null;

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        title: Text(isEditing ? 'Modifica veicolo' : 'Nuovo veicolo'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Row(
                  children: [
                    Expanded(child: _field(_brandCtrl, 'Marca')),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white70),
                      tooltip: 'Cerca nella libreria modelli',
                      onPressed: _openVehicleModelSearch,
                    ),
                  ],
                ),
                _field(_modelCtrl, 'Modello'),
                _field(
                  _yearCtrl,
                  'Anno',
                  keyboardType: TextInputType.number,
                ),
                _field(
                  _lengthCtrl,
                  'Lunghezza (m)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                _field(
                  _heightCtrl,
                  'Altezza (m)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                _field(
                  _weightCtrl,
                  'Peso (kg)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _save,
                    child: const Text('Salva camper'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openVehicleModelSearch() async {
    final selected = await Navigator.of(context).push<VehicleModelDto>(
      MaterialPageRoute(builder: (_) => const VehicleModelSearchScreen()),
    );
    if (selected == null) return;

    setState(() {
      _brandCtrl.text = selected.brand;
      _modelCtrl.text = selected.model;
      if (selected.yearFrom != null) {
        _yearCtrl.text = selected.yearFrom!.toString();
      }
      if (selected.lengthM != null) {
        _lengthCtrl.text = selected.lengthM!.toStringAsFixed(2);
      }
      if (selected.heightM != null) {
        _heightCtrl.text = selected.heightM!.toStringAsFixed(2);
      }
      if (selected.weightKg != null) {
        _weightCtrl.text = selected.weightKg!.toStringAsFixed(0);
      }
    });
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF0d221a),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF123426)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1b7f6b)),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Campo obbligatorio';
          }
          return null;
        },
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(vehiclesProvider.notifier);

    final id = widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final vehicle = Vehicle(
      id: id,
      brand: _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      year: int.tryParse(_yearCtrl.text.trim()) ?? 2000,
      lengthMeters: double.tryParse(_lengthCtrl.text.trim()) ?? 0,
      heightMeters: double.tryParse(_heightCtrl.text.trim()) ?? 0,
      weightKg: double.tryParse(_weightCtrl.text.trim()) ?? 0,
    );

    try {
      if (widget.existing == null) {
        notifier.addVehicle(vehicle);
      } else {
        notifier.updateVehicle(vehicle);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existing == null
              ? 'Camper aggiunto (mock)'
              : 'Camper aggiornato (mock)'),
        ),
      );
      Navigator.of(context).pop();
    } on StateError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}
