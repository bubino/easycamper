import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: EasyCamperApp()));
}

/// ────────────────────────── MODELS ──────────────────────────
class Camper {
  final String make;
  final String model;
  final double length;
  final double height;
  final double weight;
  final int year;
  const Camper({
    required this.make,
    required this.model,
    required this.length,
    required this.height,
    required this.weight,
    required this.year,
  });
}

class Brand {
  final String name;
  final String domain;
  final String logoAsset;
  final List<Camper> models;
  Brand({
    required this.name,
    required this.domain,
    required this.logoAsset,
    required this.models,
  });

  factory Brand.fromMap(String k, Map<String, dynamic> m) {
    final models = (m['models'] as List?) ?? [];

    // se in JSON è presente e non vuoto, usalo; altrimenti genera <brand>.png
    final rawLogo = m['logoAsset'] as String?;
    final logoAsset = (rawLogo != null && rawLogo.isNotEmpty)
        ? rawLogo
        : '${k.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), "_")}.png';

    return Brand(
      name: k,
      domain: (m['domain'] as String?) ?? '${k.toLowerCase()}.com',
      logoAsset: logoAsset,
      models: models
          .whereType<Map>()
          .map((e) => Camper(
                make: k,
                model: (e['name'] as String?) ?? 'Senza nome',
                length: (e['length'] as num? ?? 0).toDouble(),
                height: (e['height'] as num? ?? 0).toDouble(),
                weight: (e['weight'] as num? ?? 0).toDouble(),
                year: (e['year'] as int? ?? 2000),
              ))
          .toList(),
    );
  }
}

/// ────────────────────────── PROVIDERS ──────────────────────────
final camperProvider = StateProvider<Camper?>((_) => null);

final catalogProvider = FutureProvider<Map<String, Brand>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/brands.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  return data.map((k, v) => MapEntry(k, Brand.fromMap(k, v)));
});

final searchProvider = StateProvider<String>((_) => '');

/// ────────────────────────── APP & ROUTER ──────────────────────────
class EasyCamperApp extends ConsumerWidget {
  const EasyCamperApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'EasyCamper',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF4CAF50),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF4CAF50),
        ),
        routerConfig: _router,
      );
}

final _router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
  GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
  GoRoute(
    path: '/onboarding/manual',
    builder: (_, s) =>
        ManualFormScreen(custom: s.uri.queryParameters['custom'] == 'true'),
  ),
]);

/// ────────────────────────── HOME ──────────────────────────
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camper = ref.watch(camperProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('EasyCamper')),
      body: Center(
        child: camper == null
            ? ElevatedButton.icon(
                onPressed: () => context.push('/onboarding'),
                icon: const Icon(Icons.add_road_outlined),
                label: const Text('Configura il tuo camper'),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${camper.make} ${camper.model}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Anno: ${camper.year}'),
                  Text('L: ${camper.length} m  ·  H: ${camper.height} m'),
                  Text('Peso: ${camper.weight} kg'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.push('/onboarding'),
                    child: const Text('Modifica camper'),
                  ),
                ],
              ),
      ),
    );
  }
}

/// ────────────────────────── ONBOARDING ──────────────────────────
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Onboarding')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            OutlinedButton.icon(
              onPressed: () => context.push('/onboarding/manual'),
              icon: const Icon(Icons.format_list_bulleted),
              label: const Text('Seleziona da libreria modelli'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/onboarding/manual?custom=true'),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Inserisci dati manualmente'),
            ),
          ]),
        ),
      );
} // ← ecco la parentesi aggiunta

/// ────────────────────────── MANUAL FORM ──────────────────────────
class ManualFormScreen extends ConsumerStatefulWidget {
  final bool custom;
  const ManualFormScreen({super.key, required this.custom});
  @override
  ConsumerState<ManualFormScreen> createState() => _ManualFormScreenState();
}

class _ManualFormScreenState extends ConsumerState<ManualFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _lengthCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.custom
                ? 'Inserisci dati camper'
                : 'Seleziona modello')),
        body: widget.custom ? _buildManual() : _buildLibrary(),
      );

  Widget _buildManual() => Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _text(_makeCtrl, 'Marca'),
            const SizedBox(height: 12),
            _text(_modelCtrl, 'Modello'),
            const SizedBox(height: 12),
            _num(_yearCtrl, 'Anno (YYYY)'),
            const SizedBox(height: 12),
            _num(_lengthCtrl, 'Lunghezza (m)'),
            const SizedBox(height: 12),
            _num(_heightCtrl, 'Altezza (m)'),
            const SizedBox(height: 12),
            _num(_weightCtrl, 'Peso (kg)'),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _submit, child: const Text('Salva Camper')),
          ],
        ),
      );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final camper = Camper(
      make: _makeCtrl.text,
      model: _modelCtrl.text,
      year: int.tryParse(_yearCtrl.text) ?? 2000,
      length: double.tryParse(_lengthCtrl.text) ?? 0,
      height: double.tryParse(_heightCtrl.text) ?? 0,
      weight: double.tryParse(_weightCtrl.text) ?? 0,
    );
    ref.read(camperProvider.notifier).state = camper;
    context.go('/');
  }

  TextFormField _text(TextEditingController c, String label) =>
      TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        validator: (v) => v == null || v.isEmpty ? 'Campo obbligatorio' : null,
      );

  TextFormField _num(TextEditingController c, String label) =>
      TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        validator: (v) => v == null || v.isEmpty ? 'Campo obbligatorio' : null,
      );

  Widget _buildLibrary() {
    final catalog = ref.watch(catalogProvider);
    final query = ref.watch(searchProvider);
    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
      data: (brands) {
        final entries = brands.entries
            .where((e) =>
                e.key.toLowerCase().contains(query.toLowerCase()) ||
                e.value.models
                    .any((m) => m.model.toLowerCase().contains(query.toLowerCase())))
            .toList();
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Cerca modello…'),
              onChanged: (v) =>
                  ref.read(searchProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (_, i) {
                final b = entries[i].value;
                return ExpansionTile(
                  leading: _buildLogo(b),
                  title: Text(b.name),
                  children: b.models
                      .map((m) => ListTile(
                            leading: _buildLogo(b),
                            title: Text(m.model),
                            subtitle: Text(
                                'L ${m.length} m · H ${m.height} m · ${m.weight} kg'),
                            onTap: () {
                              ref.read(camperProvider.notifier).state = m;
                              context.go('/');
                            },
                          ))
                      .toList(),
                );
              },
            ),
          ),
          TextButton(
            onPressed: () =>
                context.push('/onboarding/manual?custom=true'),
            child: const Text('Modello non trovato? Aggiungilo'),
          ),
        ]);
      },
    );
  }

  Widget _buildLogo(Brand b) {
    return Image.asset(
      'assets/logos/brands/${b.logoAsset}',
      width: 32,
      height: 32,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image, size: 32),
    );
  }
}