import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        title: const Text('I miei veicoli'),
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

class _VehicleCard extends ConsumerWidget {
  final Vehicle vehicle;
  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const tileBg = Color(0xFF0d221a);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF123426)),
      ),
      child: ListTile(
        leading: const Icon(Icons.directions_bus, color: Colors.white),
        title: Text(
          '${vehicle.brand} ${vehicle.model} (${vehicle.year})',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          'Lunghezza: ${vehicle.lengthMeters.toStringAsFixed(2)} m, '
          'Altezza: ${vehicle.heightMeters.toStringAsFixed(2)} m, '
          'Peso: ${vehicle.weightKg.toStringAsFixed(0)} kg',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VehicleFormScreen(existing: vehicle),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () {
                ref.read(vehiclesProvider.notifier).removeVehicle(vehicle.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
