import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

import 'http_client.dart';
import 'spot_dto.dart';
import 'auth_state.dart';

class SpotMarkerData {
  final String id;
  final String? userId;
  final String name;
  final String? shortDescription;
  final double latitude;
  final double longitude;
  // Nuovi campi opzionali per i filtri
  final String? type; // es. 'area_sosta', 'campeggio', 'agricampeggio'
  final List<String> services;
  final double? rating;
  final List<String> photos;

  SpotMarkerData({
    required this.id,
    this.userId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.shortDescription,
    this.type,
    this.services = const [],
    this.rating,
    this.photos = const [],
  });

  factory SpotMarkerData.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] ?? json['lat']) as num?;
    final lng = (json['longitude'] ?? json['lng']) as num?;

    return SpotMarkerData(
      id: json['id'].toString(),
      userId: json['userId']?.toString(),
      name: (json['name'] as String?) ?? '',
      latitude: (lat ?? 0).toDouble(),
      longitude: (lng ?? 0).toDouble(),
      shortDescription:
          (json['shortDescription'] ?? json['description']) as String?,
      type: json['type'] as String?,
      services: _parseServices(json['services']),
      rating: ((json['ratingAverage'] ?? json['rating']) as num?)?.toDouble(),
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  static List<String> _parseServices(dynamic raw) {
    // Backend stores services as JSON object: { electricity: true, water: true, ... }
    // Mock uses a list of strings.
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is Map) {
      final out = <String>[];
      raw.forEach((k, v) {
        if (v == true) out.add(k.toString());
      });
      return out;
    }
    return const [];
  }
}

class SpotCreateDto {
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final String type; // es. 'area_sosta'
  final Map<String, bool> services; // chiavi allineate al backend (es. "Elettricità")

  /// Valutazione iniziale fornita dall'utente (1..5). Facoltativa.
  final int? rating;

  SpotCreateDto({
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.services,
    this.rating,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'type': type,
        'services': services,
        if (rating != null) 'rating': rating,
      };
}

class SpotUpdateDto {
  final String? name;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String? type;
  final Map<String, bool>? services;
  final int? rating;

  SpotUpdateDto({
    this.name,
    this.description,
    this.latitude,
    this.longitude,
    this.type,
    this.services,
    this.rating,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (type != null) 'type': type,
        if (services != null) 'services': services,
        if (rating != null) 'rating': rating,
      };
}

class SpotsApiClient {
  final String baseUrl;
  final ApiHttpClient _http;

  // Cache in-memory (best effort) per dettagli spot
  final Map<String, SpotDto> _spotCache = {};

  SpotsApiClient(this.baseUrl, ApiHttpClient httpClient) : _http = httpClient;

  SpotDto? getCachedSpot(String id) => _spotCache[id];

  void _cacheSpot(SpotDto spot) {
    _spotCache[spot.id] = spot;
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

    if (kDebugMode) {
      debugPrint(
        'SPOTS API DEBUG: baseUrl=$baseUrl bbox=${query['bbox']} types=${types ?? const []} services=${services ?? const []} minRating=$minRating',
      );
    }

    // Allineato a server/app.js: app.use('/spots', authenticate, require('./routes/spots'));
    final resp = await _http.get(
      '/spots',
      queryParameters: query,
      authenticated: true,
    );

    if (resp.statusCode != 200) {
      if (kDebugMode) {
        final snippet = resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body;
        debugPrint('SPOTS API DEBUG: status=${resp.statusCode} body=$snippet');
      }
      throw Exception('Errore caricamento spots: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (kDebugMode) {
      debugPrint('SPOTS API DEBUG: response keys=${data.keys.toList()} total=${data['total']}');
    }
    final spotsJson = data['spots'] as List<dynamic>? ?? const [];

    return spotsJson
        .map((e) => SpotMarkerData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SpotDto?> _loadMockSpotById(String id) async {
    try {
      final raw = await rootBundle.loadString('mock_data/spot.json');
      final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
      final match = jsonList
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['id'].toString() == id, orElse: () => {});
      if (match.isEmpty) return null;
      return SpotDto.fromJson(match);
    } catch (_) {
      return null;
    }
  }

  Future<SpotDto> fetchSpotById(String id) async {
    final cached = _spotCache[id];
    if (cached != null) return cached;

    http.Response? resp;
    try {
      resp = await _http.get('/spots/$id', authenticated: true);
    } catch (_) {
      // ignore
    }

    // If missing token or any auth problem, try mock fallback for dev.
    if (resp == null || resp.statusCode == 401 || resp.statusCode == 403) {
      final mock = await _loadMockSpotById(id);
      if (mock != null) {
        _cacheSpot(mock);
        return mock;
      }
    }

    if (resp == null) {
      throw Exception('Backend non raggiungibile');
    }

    if (resp.statusCode != 200) {
      throw Exception('Errore caricamento spot $id: ${resp.statusCode}');
    }

    final body = jsonDecode(resp.body);

    Map<String, dynamic> json;
    if (body is Map<String, dynamic>) {
      if (body['spot'] is Map<String, dynamic>) {
        json = body['spot'] as Map<String, dynamic>;
      } else {
        json = body;
      }
    } else {
      throw Exception('Risposta non valida per spot $id');
    }

    final spot = SpotDto.fromJson(json);
    _cacheSpot(spot);
    return spot;
  }

  Future<SpotDto> updateSpot(String id, SpotUpdateDto dto) async {
    final resp = await _http.put(
      '/spots/$id',
      body: jsonEncode(dto.toJson()),
      headers: const {'Content-Type': 'application/json'},
      authenticated: true,
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Errore aggiornamento spot: ${resp.statusCode}');
    }

    final body = jsonDecode(resp.body);
    Map<String, dynamic> json;
    if (body is Map<String, dynamic> && body['spot'] is Map<String, dynamic>) {
      json = body['spot'] as Map<String, dynamic>;
    } else if (body is Map<String, dynamic>) {
      json = body;
    } else {
      throw Exception('Risposta non valida per update spot');
    }

    final spot = SpotDto.fromJson(json);
    _cacheSpot(spot);
    return spot;
  }

  Future<void> deleteSpot(String id) async {
    final resp = await _http.delete(
      '/spots/$id',
      authenticated: true,
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Errore eliminazione spot: ${resp.statusCode}');
    }

    _spotCache.remove(id);
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

    final created = jsonDecode(resp.body) as Map<String, dynamic>;

    // best-effort: se il backend ritorna i campi completi spot, mettili in cache
    try {
      final maybeSpotJson =
          created['spot'] is Map<String, dynamic> ? created['spot'] : created;
      final maybeSpot = SpotDto.fromJson(maybeSpotJson as Map<String, dynamic>);
      _cacheSpot(maybeSpot);

      // Se abbiamo un id valido, ricarichiamo i dettagli per evitare dati parziali
      // (es. ratingAverage/ratingCount non presenti o non coerenti nella response).
      if (maybeSpot.id.isNotEmpty) {
        try {
          final detailResp = await _http.get(
            '/spots/${maybeSpot.id}',
            authenticated: true,
          );
          if (detailResp.statusCode == 200) {
            final detailJson = jsonDecode(detailResp.body);
            if (detailJson is Map<String, dynamic>) {
              final spot = SpotDto.fromJson(detailJson);
              _cacheSpot(spot);
            }
          }
        } catch (_) {
          // ignore
        }
      }
    } catch (_) {
      // ignore
    }

    return created;
  }

  Future<Map<String, dynamic>> getSpotPhotoUploadUrl(String spotId) async {
    final resp = await _http.get(
      '/api/uploads/spots/$spotId/photo-url',
      authenticated: true,
    );
    if (resp.statusCode != 200) {
      throw Exception('Errore presigned upload url: ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createSpotPhotoPublicUrl(
    String spotId, {
    required String key,
  }) async {
    final resp = await _http.post(
      '/api/uploads/spots/$spotId/photo',
      authenticated: true,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'key': key}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Errore creazione public url: ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<void> addSpotPhotos(
    String spotId, {
    required List<String> urls,
  }) async {
    final resp = await _http.post(
      '/spots/$spotId/photos',
      authenticated: true,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'urls': urls}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Errore commit foto spot: ${resp.statusCode}');
    }

    // Aggiorna best-effort la cache dettagli
    try {
      final cached = _spotCache[spotId];
      if (cached != null) {
        final merged = [...cached.photos];
        for (final u in urls) {
          if (!merged.contains(u)) merged.add(u);
        }
        _spotCache[spotId] = SpotDto(
          id: cached.id,
          userId: cached.userId,
          name: cached.name,
          lat: cached.lat,
          lng: cached.lng,
          type: cached.type,
          description: cached.description,
          services: cached.services,
          rating: cached.rating,
          photos: merged,
        );
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> uploadBytesToPresignedUrl(
    String presignedUrl, {
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final uri = Uri.parse(presignedUrl);
    final resp = await http.put(uri, headers: {'Content-Type': contentType}, body: bytes);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Errore PUT presigned upload: ${resp.statusCode}');
    }
  }
}

final spotsApiClientProvider = Provider<SpotsApiClient>((ref) {
  // Su iPhone reale 127.0.0.1 punta al device, non al Mac.
  // Permettiamo override via .env: API_BASE_URL=http://<IP_DEL_MAC>:3000
  String? envBaseUrl;
  try {
    envBaseUrl = dotenv.env['API_BASE_URL'];
  } catch (_) {
    envBaseUrl = null;
  }

  final baseUrl = (envBaseUrl != null && envBaseUrl.trim().isNotEmpty)
      ? envBaseUrl.trim()
      : kAuthBaseUrl;

  final httpClient = ref.read(apiHttpClientProvider);
  return SpotsApiClient(baseUrl, httpClient);
});
