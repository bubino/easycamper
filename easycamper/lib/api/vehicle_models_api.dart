import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'http_client.dart';

/// DTO per i modelli di veicolo restituiti da /api/vehicle-models
class VehicleModelDto {
  final String id;
  final String brand;
  final String model;
  final int? yearFrom;
  final double? lengthM;
  final double? heightM;
  final double? weightKg;
  final String? type;
  final String? brandSlug;

  VehicleModelDto({
    required this.id,
    required this.brand,
    required this.model,
    this.yearFrom,
    this.lengthM,
    this.heightM,
    this.weightKg,
    this.type,
    this.brandSlug,
  });

  factory VehicleModelDto.fromJson(Map<String, dynamic> json) {
    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return VehicleModelDto(
      id: json['id']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      yearFrom: json['year_from'] is int ? json['year_from'] as int : int.tryParse(json['year_from']?.toString() ?? ''),
      lengthM: _toDouble(json['length_m']),
      heightM: _toDouble(json['height_m']),
      weightKg: _toDouble(json['weight_kg']),
      type: json['type']?.toString(),
      brandSlug: json['brand_slug']?.toString(),
    );
  }
}

/// Client semplice per /api/vehicle-models.
class VehicleModelsApi {
  final ApiHttpClient _http;

  VehicleModelsApi(this._http);

  Future<List<VehicleModelDto>> searchVehicleModels({
    String? search,
    String? brand,
    int limit = 20,
    int offset = 0,
  }) async {
    final query = {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
      'limit': limit,
      'offset': offset,
    };

    final res = await _http.get(
      '/api/vehicle-models',
      queryParameters: query,
      authenticated: true, // Assumiamo che serva autenticazione, o false se pubblica
    );

    if (res.statusCode != 200) {
      throw Exception('Errore ${res.statusCode} nel caricamento dei modelli veicolo');
    }

    final Map<String, dynamic> body = json.decode(res.body) as Map<String, dynamic>;
    final List<dynamic> data = body['data'] as List<dynamic>? ?? const [];
    return data.map((e) => VehicleModelDto.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final vehicleModelsApiProvider = Provider<VehicleModelsApi>((ref) {
  final httpClient = ref.read(apiHttpClientProvider);
  return VehicleModelsApi(httpClient);
});
