import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/vehicle_models_api.dart';

class VehicleModelSearchScreen extends ConsumerStatefulWidget {
  const VehicleModelSearchScreen({super.key});

  @override
  ConsumerState<VehicleModelSearchScreen> createState() => _VehicleModelSearchScreenState();
}

class _VehicleModelSearchScreenState extends ConsumerState<VehicleModelSearchScreen> {
  late final VehicleModelsApi _api;
  final _searchController = TextEditingController();

  bool _loading = false;
  String? _error;
  List<VehicleModelDto> _results = [];

  @override
  void initState() {
    super.initState();
    _api = VehicleModelsApi(ref: ref);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.searchVehicleModels(search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim());
      setState(() {
        _results = list;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cerca modello veicolo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Cerca per marca o modello',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _loading ? null : _load,
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (_results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nessun modello trovato.'),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final m = _results[index];
                  final subtitleParts = <String>[];
                  if (m.yearFrom != null) subtitleParts.add('dal ${m.yearFrom}');
                  if (m.lengthM != null) subtitleParts.add('L: ${m.lengthM} m');
                  if (m.heightM != null) subtitleParts.add('H: ${m.heightM} m');
                  if (m.widthM != null) subtitleParts.add('W: ${m.widthM} m');
                  if (m.weightKg != null) subtitleParts.add('Peso: ${m.weightKg} kg');

                  return ListTile(
                    title: Text('${m.brand} ${m.model}'),
                    subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' • ')),
                    onTap: () => Navigator.of(context).pop<VehicleModelDto>(m),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
