import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'http_client.dart';

class SpotDto {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String? type;
  final List<String> services;
  final double rating;

  const SpotDto({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.type,
    this.services = const [],
    this.rating = 0,
  });

  factory SpotDto.fromJson(Map<String, dynamic> json) {
    return SpotDto(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      latitude: (json['lat'] as num?)?.toDouble() ??
          (json['latitude'] as num?)?.toDouble() ??
          0,
      longitude: (json['lng'] as num?)?.toDouble() ??
          (json['longitude'] as num?)?.toDouble() ??
          0,
      type: json['type'] as String?,
      services: (json['services'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SpotMarkerData {
  final String id;
  final String name;
  final String? shortDescription;
  final double latitude;
  final double longitude;
  // Nuovi campi opzionali per i filtri
  final String? type; // es. 'area_sosta', 'campeggio', 'agricampeggio'
  final List<String> services;
  final double? rating;

  SpotMarkerData({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.shortDescription,
    this.type,
    this.services = const [],
    this.rating,
  });

  factory SpotMarkerData.fromJson(Map<String, dynamic> json) {
    return SpotMarkerData(
      id: json['id'].toString(),
      name: json['name'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      shortDescription: json['description'] as String?,
      type: json['type'] as String?,
      services: (json['services'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}

class SpotCreateDto {
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final String type; // es. 'area_sosta'
  final Map<String, bool> services; // chiavi allineate al backend (es. "Elettricità")

  SpotCreateDto({
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.services,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'type': type,
        'services': services,
      };
}

class SpotsApiClient {
  final String baseUrl;
  final ApiHttpClient _http;

  SpotsApiClient(this.baseUrl, ApiHttpClient httpClient) : _http = httpClient;

  // In-memory cache for full spot details
  final Map<String, SpotDto> _spotCache = {};

  SpotDto? getCachedSpot(String id) => _spotCache[id];

  Future<SpotDto> fetchSpotById(String id) async {
    final resp = await _http.get(
      '/spots/$id',
      authenticated: true,
    );

    if (resp.statusCode != 200) {
      throw Exception('Errore caricamento spot $id: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final dto = SpotDto.fromJson(data['spot'] as Map<String, dynamic>);
    _spotCache[dto.id] = dto;
    return dto;
  }

  Future<List<SpotMarkerData>> fetchSpotsForBBox({
    required double latMin,
    required double lngMin,
    required double latMax,
    required double lngMax,
    List<String>? types,
    List<String>? services,
    double? minRating,
  }) async {
    final query = <String, dynamic>{
      'bbox': '$latMin,$lngMin,$latMax,$lngMax',
      if (types != null && types.isNotEmpty) 'types': types,
      if (services != null && services.isNotEmpty) 'services': services,
      if (minRating != null) 'minRating': minRating,
    };

    // Allineato a server/app.js: app.use('/spots', authenticate, require('./routes/spots'));
    final resp = await _http.get(
      '/spots',
      queryParameters: query,
      authenticated: true,
    );

    if (resp.statusCode != 200) {
      throw Exception('Errore caricamento spots: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final spotsJson = data['spots'] as List<dynamic>? ?? const [];

    return spotsJson
        .map((e) => SpotMarkerData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> createSpot(SpotCreateDto dto) async {
    final resp = await _http.post(
      '/spots',
      body: jsonEncode(dto.toJson()),
      headers: const {'Content-Type': 'application/json'},
      authenticated: true,
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Errore creazione spot: ${resp.statusCode}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}

final spotsApiClientProvider = Provider<SpotsApiClient>((ref) {
  const baseUrl = 'http://127.0.0.1:3000';
  final httpClient = ref.read(apiHttpClientProvider);
  return SpotsApiClient(baseUrl, httpClient);
});
