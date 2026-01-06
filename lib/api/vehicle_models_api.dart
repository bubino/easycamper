import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Importo la stessa base URL di default usata dall'autenticazione (device fisico).
import 'auth_state.dart';

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
  VehicleModelsApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _resolveBaseUrlFromEnv();

  static String _resolveBaseUrlFromEnv() {
    try {
      final v = dotenv.env['API_BASE_URL'];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    } catch (_) {
      // ignore
    }

    // Su device fisico iOS/Android 127.0.0.1 punta al device, non al Mac.
    // Allineiamo al backend usato per auth.
    return kAuthBaseUrl;
  }

  final http.Client _client;
  final String _baseUrl;

  Future<List<VehicleModelDto>> searchVehicleModels({
    String? search,
    String? brand,
    int limit = 20,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/vehicle-models').replace(
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Errore ${res.statusCode} nel caricamento dei modelli veicolo');
    }

    final Map<String, dynamic> body = json.decode(res.body) as Map<String, dynamic>;
    final List<dynamic> data = body['data'] as List<dynamic>? ?? const [];
    return data.map((e) => VehicleModelDto.fromJson(e as Map<String, dynamic>)).toList();
  }
}
