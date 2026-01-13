import 'package:flutter_riverpod/flutter_riverpod.dart';

class Vehicle {
  final String id;
  final String brand;
  final String model;
  final int year;
  final double lengthMeters;
  final double heightMeters;
  final double widthMeters;
  final double weightKg;

  /// Path locale dell'immagine associata al veicolo (opzionale).
  final String? imagePath;

  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.lengthMeters,
    required this.heightMeters,
    required this.widthMeters,
    required this.weightKg,
    this.imagePath,
  });

  Vehicle copyWith({
    String? id,
    String? brand,
    String? model,
    int? year,
    double? lengthMeters,
    double? heightMeters,
    double? widthMeters,
    double? weightKg,
    String? imagePath,
    bool clearImagePath = false,
  }) {
    return Vehicle(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      lengthMeters: lengthMeters ?? this.lengthMeters,
      heightMeters: heightMeters ?? this.heightMeters,
      widthMeters: widthMeters ?? this.widthMeters,
      weightKg: weightKg ?? this.weightKg,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
    );
  }
}

class VehiclesNotifier extends Notifier<List<Vehicle>> {
  @override
  List<Vehicle> build() => [];

  static const int maxVehicles = 2;

  void addVehicle(Vehicle v) {
    if (state.length >= maxVehicles) {
      throw StateError('Puoi salvare al massimo $maxVehicles veicoli');
    }
    state = [...state, v];
  }

  void updateVehicle(Vehicle v) {
    state = [
      for (final current in state)
        if (current.id == v.id) v else current,
    ];
  }

  void removeVehicle(String id) {
    state = [for (final v in state) if (v.id != id) v];
  }
}

final vehiclesProvider = NotifierProvider<VehiclesNotifier, List<Vehicle>>(
  VehiclesNotifier.new,
);
