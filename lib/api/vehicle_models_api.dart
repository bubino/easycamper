import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  final double? widthM;
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
    this.widthM,
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
      widthM: _toDouble(json['width_m']),
      weightKg: _toDouble(json['weight_kg']),
      type: json['type']?.toString(),
      brandSlug: json['brand_slug']?.toString(),
    );
  }
}

/// Client semplice per /api/vehicle-models.
/// In futuro possiamo centralizzare la baseUrl (es. da env/config), per ora usiamo localhost:5000.
class VehicleModelsApi {
  final ProviderRefBase ref;
  final ApiHttpClient _http;

  VehicleModelsApi({required ProviderRefBase ref, ApiHttpClient? httpClient, String? baseUrl})
      : ref = ref,
        _http = httpClient ?? ApiHttpClient(baseUrl: baseUrl ?? _resolveBaseUrlFromEnv(), ref: ref);

  static String _resolveBaseUrlFromEnv() {
    try {
      final v = dotenv.env['API_BASE_URL'];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    } catch (_) {
      // ignore
    }

    // fallback: se non configurato, usa il default dell'app (vedi ApiHttpClient)
    return dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000';
  }

  Future<List<VehicleModelDto>> searchVehicleModels({
    String? search,
    String? brand,
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _http.get<dynamic>(
      '/api/vehicle-models',
      authenticated: false,
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
        'limit': limit,
        'offset': offset,
      },
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Errore ${res.statusCode} nel caricamento dei modelli veicolo',
      );
    }

    final Map<String, dynamic> body = (res.data is Map)
        ? Map<String, dynamic>.from(res.data as Map)
        : json.decode(res.data?.toString() ?? '{}') as Map<String, dynamic>;
    final List<dynamic> data = body['data'] as List<dynamic>? ?? const [];
    return data.map((e) => VehicleModelDto.fromJson(e as Map<String, dynamic>)).toList();
  }
}
