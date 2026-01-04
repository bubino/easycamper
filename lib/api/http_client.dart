import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'auth_state.dart';

class ApiHttpClient {
  final String baseUrl;
  final Ref ref;
  final http.Client _client;

  ApiHttpClient({
    required this.baseUrl,
    required this.ref,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    bool authenticated = true,
  }) async {
    return _send(
      'GET',
      path,
      headers: headers,
      queryParameters: queryParameters,
      authenticated: authenticated,
    );
  }

  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    bool authenticated = true,
  }) async {
    return _send(
      'POST',
      path,
      headers: headers,
      body: body,
      authenticated: authenticated,
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
    bool authenticated = true,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final effectiveHeaders = <String, String>{
      'Content-Type': 'application/json',
      ...?headers,
    };

    String? token;
    if (authenticated) {
      final authState = ref.read(authControllerProvider);
      token = authState.value?.session?.accessToken;
      if (token != null && token.isNotEmpty) {
        effectiveHeaders['Authorization'] = 'Bearer $token';
      }
    }

    http.Response response = await _execute(method, uri, effectiveHeaders, body);

    if (authenticated && _isAuthError(response.statusCode)) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        final newAuthState = ref.read(authControllerProvider);
        final newToken = newAuthState.value?.session?.accessToken;
        if (newToken != null && newToken.isNotEmpty) {
          effectiveHeaders['Authorization'] = 'Bearer $newToken';
        } else {
          effectiveHeaders.remove('Authorization');
        }
        response = await _execute(method, uri, effectiveHeaders, body);
      } else {
        await ref.read(authControllerProvider.notifier).logout();
      }
    }

    return response;
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParameters) {
    final uri = Uri.parse('$baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        ...queryParameters.map((k, v) => MapEntry(k, v.toString())),
      },
    );
  }

  Future<http.Response> _execute(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) async {
    switch (method.toUpperCase()) {
      case 'GET':
        return _client.get(uri, headers: headers);
      case 'POST':
        return _client.post(uri, headers: headers, body: body);
      case 'PUT':
        return _client.put(uri, headers: headers, body: body);
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: body);
      case 'DELETE':
        return _client.delete(uri, headers: headers, body: body);
      default:
        throw UnsupportedError('Metodo HTTP non supportato: $method');
    }
  }

  bool _isAuthError(int statusCode) {
    return statusCode == 401 || statusCode == 403;
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final storage = ref.read(authStorageProvider);
      final authApi = ref.read(authApiClientProvider);
      final refreshResult = await authApi.refreshToken();
      await storage.saveSession(refreshResult);
      final controller = ref.read(authControllerProvider.notifier);
      controller.setSessionFromResult(refreshResult);
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('REFRESH DEBUG: errore durante /auth/refresh: $e');
        debugPrint(st.toString());
      }
      return false;
    }
  }
}

final apiHttpClientProvider = Provider<ApiHttpClient>((ref) {
  const baseUrl = 'http://127.0.0.1:3000';
  return ApiHttpClient(baseUrl: baseUrl, ref: ref);
});
