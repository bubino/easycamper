import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/http_client.dart';

class PersonalDataScreen extends ConsumerStatefulWidget {
  final String? initialEmail;
  const PersonalDataScreen({super.key, this.initialEmail});

  @override
  ConsumerState<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends ConsumerState<PersonalDataScreen> {
  final _formKey = GlobalKey<FormState>();

  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _language = 'it';

  final _newEmailController = TextEditingController();
  bool _changingEmail = false;

  @override
  void initState() {
    super.initState();
    _email = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    _newEmailController.dispose();
    super.dispose();
  }

  Future<void> _requestEmailChange() async {
    final newEmail = _newEmailController.text.trim();
    if (newEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci una nuova email.')),
      );
      return;
    }

    // Recupera la sessione di autenticazione corrente da Riverpod
    final authAsync = ref.read(authControllerProvider);
    final session = authAsync.value?.session;

    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devi essere loggato per cambiare email.')),
      );
      return;
    }

    final userId = session.userId;
    final token = session.accessToken;

    setState(() => _changingEmail = true);
    try {
      final baseUrl = ref.read(apiHttpClientProvider).baseUrl;
      final uri = Uri.parse('$baseUrl/users/$userId/change-email');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'newEmail': newEmail}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        _newEmailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Richiesta cambio email inviata. Controlla la nuova casella per confermare.',
            ),
          ),
        );
      } else {
        String msg = 'Errore nel cambio email';
        try {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          if (body['error'] is String) msg = body['error'] as String;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore di rete: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _changingEmail = false);
      }
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
        foregroundColor: Colors.white, // testo e freccia back ben visibili
        elevation: 0,
        title: const Text('Dati personali'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                _buildTextField(
                  label: 'Nome',
                  initialValue: _firstName,
                  onSaved: (v) => _firstName = v?.trim() ?? '',
                ),
                _buildTextField(
                  label: 'Cognome',
                  initialValue: _lastName,
                  onSaved: (v) => _lastName = v?.trim() ?? '',
                ),
                _buildTextField(
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  initialValue: _email,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Inserisci una email';
                    }
                    if (!v.contains('@')) {
                      return 'Email non valida';
                    }
                    return null;
                  },
                  onSaved: (v) => _email = v!.trim(),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lingua preferita',
                  style: TextStyle(
                    color: Colors.white, // label leggibile su sfondo scuro
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0d221a),
                    borderRadius: BorderRadius.circular(16),
                    border: const Border.fromBorderSide(
                      BorderSide(color: Color(0xFF123426)),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _language,
                      dropdownColor: const Color(0xFF0d221a),
                      iconEnabledColor: Colors.white70,
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(
                          value: 'it',
                          child: Text('Italiano (it)'),
                        ),
                        DropdownMenuItem(
                          value: 'de',
                          child: Text('Deutsch (de)'),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text('English (en)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _language = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Cambia email',
                  style: TextStyle(
                    color: Colors.white, // titolo sezione leggibile
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nuova email',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF0d221a),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF123426)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: primary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _changingEmail ? null : _requestEmailChange,
                    child: _changingEmail
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Richiedi cambio email'),
                  ),
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
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        _formKey.currentState?.save();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Dati salvati (mock): $_firstName $_lastName, $_email, lingua: $_language',
                            ),
                          ),
                        );
                        // Torna alla schermata precedente (Profilo)
                        Navigator.of(context).pop('saved');
                      }
                    },
                    child: const Text('Salva'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    String? initialValue,
    TextInputType? keyboardType,
    FormFieldSetter<String>? onSaved,
    FormFieldValidator<String>? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        style: const TextStyle(color: Colors.white),
        initialValue: initialValue,
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
        onSaved: onSaved,
        validator: validator,
      ),
    );
  }
}
