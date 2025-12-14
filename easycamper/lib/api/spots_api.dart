import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  final List<String> photos;

  const SpotDto({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.type,
    this.services = const [],
    this.rating = 0,
    this.photos = const [],
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
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
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
      name: json['name'] as String? ?? 'Senza nome',
      latitude: (json['lat'] as num?)?.toDouble() ?? 
                (json['latitude'] as num?)?.toDouble() ?? 
                0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 
                 (json['longitude'] as num?)?.toDouble() ?? 
                 0.0,
      shortDescription: json['description'] as String?,
      // Se il tipo è nullo, assegniamo 'area_sosta' come default per garantire visibilità
      type: (json['type'] as String?) ?? 'area_sosta',
      services: (json['services'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': latitude,
      'lng': longitude,
      'description': shortDescription,
      'type': type,
      'services': services,
      'rating': rating,
    };
  }
}

class SpotCreateDto {
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final String type; // es. 'area_sosta'
  final List<String> services; // Lista di chiavi backend (es. "electricity")
  final List<String> photos;

  SpotCreateDto({
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.services,
    this.photos = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'type': type,
        'services': services,
        'photos': photos,
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
    try {
      final resp = await _http.get(
        '/spots/$id',
        authenticated: true,
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final dto = SpotDto.fromJson(data['spot'] as Map<String, dynamic>);
        _spotCache[dto.id] = dto;
        return dto;
      }
    } catch (e) {
      // Ignoriamo l'errore per provare il fallback
    }

    // Fallback ai mock se l'API fallisce
    final mocks = await _loadMockSpots();
    try {
      final found = mocks.firstWhere((s) => s.id == id);
      _spotCache[found.id] = found;
      return found;
    } catch (_) {
      throw Exception('Spot $id non trovato (nemmeno nei mock)');
    }
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
    try {
      final query = <String, dynamic>{
        'latitude': ((latMin + latMax) / 2).toString(),
        'longitude': ((lngMin + lngMax) / 2).toString(),
        if (types != null && types.isNotEmpty) 'type': types.join(','),
        if (services != null && services.isNotEmpty) 'services': services.join(','),
      };

      final resp = await _http.get(
        '/public-spots',
        queryParameters: query,
        authenticated: true,
      );

      if (resp.statusCode == 200) {
        final List<dynamic> spotsJson = jsonDecode(resp.body) as List<dynamic>;

        return spotsJson
            .map((e) => SpotMarkerData.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Errore fetchSpotsForBBox: $e');
      // Fallback ai mock
    }

    // Logica di filtraggio sui mock
    final allMocks = await _loadMockSpots();
    return allMocks.where((s) {
      // BBox check
      if (s.latitude < latMin || s.latitude > latMax) return false;
      if (s.longitude < lngMin || s.longitude > lngMax) return false;

      // Type check
      if (types != null && types.isNotEmpty) {
        if (s.type == null || !types.contains(s.type)) return false;
      }

      // Services check
      if (services != null && services.isNotEmpty) {
        final sServices = s.services.toSet();
        final hasAny = services.any((req) => sServices.contains(req));
        if (!hasAny) return false;
      }

      // Rating check
      if (minRating != null && minRating > 0) {
        if (s.rating < minRating) return false;
      }

      return true;
    }).map((s) {
      return SpotMarkerData(
        id: s.id,
        name: s.name,
        latitude: s.latitude,
        longitude: s.longitude,
        shortDescription: s.description,
        type: s.type,
        services: s.services,
        rating: s.rating,
      );
    }).toList();
  }

  Future<List<SpotDto>> _loadMockSpots() async {
    try {
      final jsonString = await rootBundle.loadString('mock_data/spot.json');
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => SpotDto.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
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

  Future<String> uploadImage(File file) async {
    // Endpoint backend: POST /api/uploads (definito in server/routes/uploads.js)
    // Ritorna JSON { "url": "..." }
    
    // Usiamo multipartPost del client HTTP
    final resp = await _http.multipartPost(
      '/uploads',
      files: [
        await http.MultipartFile.fromPath('image', file.path),
      ],
      authenticated: true,
    );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Upload fallito (${resp.statusCode})');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['url'] as String;
  }
}

final spotsApiClientProvider = Provider<SpotsApiClient>((ref) {
  // 1. Se definito nel .env, usa quello (utile per device fisici: http://192.168.x.x:3000)
  final envUrl = dotenv.env['API_URL'];
  if (envUrl != null && envUrl.isNotEmpty) {
    final httpClient = ref.read(apiHttpClientProvider);
    return SpotsApiClient(envUrl, httpClient);
  }

  // 2. Altrimenti usa la logica automatica per emulatori
  // - Android Emulator: 10.0.2.2
  // - iOS Simulator / macOS: 127.0.0.1
  String baseUrl = 'http://127.0.0.1:3000';
  
  if (Platform.isAndroid) {
    baseUrl = 'http://10.0.2.2:3000';
  }
  
  final httpClient = ref.read(apiHttpClientProvider);
  return SpotsApiClient(baseUrl, httpClient);
});
