import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/vehicle_state.dart';

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
  final _widthCtrl = TextEditingController(); // nuova larghezza in metri

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
    _widthCtrl.text = v?.widthMeters.toString() ?? '';
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _lengthCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _widthCtrl.dispose();
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
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        title: Text(isEditing ? 'Modifica veicolo' : 'Nuovo veicolo'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                _field(_brandCtrl, 'Marca'),
                _field(_modelCtrl, 'Modello'),
                _field(
                  _yearCtrl,
                  'Anno',
                  keyboardType: TextInputType.number,
                  validator: _validateYear,
                ),
                _field(
                  _lengthCtrl,
                  'Lunghezza (m)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateDoubleMeters(v, label: 'Lunghezza', min: 2.0, max: 20.0),
                ),
                _field(
                  _heightCtrl,
                  'Altezza (m)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateDoubleMeters(v, label: 'Altezza', min: 1.5, max: 6.0),
                ),
                _field(
                  _widthCtrl,
                  'Larghezza (m)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateDoubleMeters(v, label: 'Larghezza', min: 1.0, max: 4.0),
                ),
                _field(
                  _weightCtrl,
                  'Peso (kg)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _validateWeightKg,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nota: i dati di lunghezza/altezza/larghezza/peso sono obbligatori per poter usare la navigazione camper-aware.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
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

  String? _validateYear(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Campo obbligatorio';
    final year = int.tryParse(v);
    if (year == null) return 'Inserisci un anno valido';
    if (year < 1950 || year > DateTime.now().year + 1) {
      return 'Anno non valido';
    }
    return null;
  }

  String? _validateDoubleMeters(
    String? value, {
    required String label,
    required double min,
    required double max,
  }) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Campo obbligatorio';

    // Accetta virgola come separatore decimale
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed == null) return '$label: numero non valido';
    if (parsed < min || parsed > max) {
      return '$label: valore fuori range';
    }
    return null;
  }

  String? _validateWeightKg(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Campo obbligatorio';
    final parsed = double.tryParse(raw.replaceAll(',', '.'));
    if (parsed == null) return 'Peso: numero non valido';
    if (parsed < 500 || parsed > 20000) return 'Peso: valore fuori range';
    return null;
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
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
        validator: validator ?? (value) {
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

    double _parseDouble(String s) => double.parse(s.trim().replaceAll(',', '.'));

    final vehicle = Vehicle(
      id: id,
      brand: _brandCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      year: int.parse(_yearCtrl.text.trim()),
      lengthMeters: _parseDouble(_lengthCtrl.text),
      heightMeters: _parseDouble(_heightCtrl.text),
      widthMeters: _parseDouble(_widthCtrl.text),
      weightKg: _parseDouble(_weightCtrl.text),
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
