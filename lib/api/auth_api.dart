import 'dart:convert';
import 'package:dio/dio.dart';

import 'http_client.dart';
import 'auth_result.dart';

class AuthApiClient {
  final String baseUrl;
  final ApiHttpClient _http;

  AuthApiClient(this.baseUrl, this._http);

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final resp = await _http.post<dynamic>(
      '/auth/register',
      authenticated: false,
      headers: const {'Content-Type': 'application/json'},
      data: {'username': username, 'email': email, 'password': password},
    );

    if (resp.statusCode != 201) {
      String message = 'Registrazione fallita (${resp.statusCode})';
      try {
        final data =
            (resp.data is Map)
                ? Map<String, dynamic>.from(resp.data as Map)
                : jsonDecode(resp.data?.toString() ?? '{}')
                    as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        } else if (data['message'] is String) {
          message = data['message'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }

    // Nessun AuthResult: il server non restituisce token alla registrazione.
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final resp = await _http.post<dynamic>(
      '/auth/login',
      authenticated: false,
      headers: const {'Content-Type': 'application/json'},
      data: {'email': email, 'password': password},
    );

    if (resp.statusCode != 200) {
      String message = 'Login fallito (${resp.statusCode})';
      try {
        final data =
            (resp.data is Map)
                ? Map<String, dynamic>.from(resp.data as Map)
                : jsonDecode(resp.data?.toString() ?? '{}')
                    as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data =
        (resp.data is Map)
            ? Map<String, dynamic>.from(resp.data as Map)
            : jsonDecode(resp.data?.toString() ?? '{}') as Map<String, dynamic>;
    return AuthResult.fromJson(data);
  }

  Future<void> requestPasswordReset(String email) async {
    final resp = await _http.post<dynamic>(
      '/auth/request-reset-password',
      authenticated: false,
      headers: const {'Content-Type': 'application/json'},
      data: {'email': email},
    );

    if (resp.statusCode != 200) {
      String message = 'Invio email di reset fallito (${resp.statusCode})';
      try {
        final data =
            (resp.data is Map)
                ? Map<String, dynamic>.from(resp.data as Map)
                : jsonDecode(resp.data?.toString() ?? '{}')
                    as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        } else if (data['message'] is String) {
          message = data['message'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  Future<void> logout() async {
    final resp = await _http.post<dynamic>('/auth/logout', authenticated: true);
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      try {
        final data =
            (resp.data is Map)
                ? Map<String, dynamic>.from(resp.data as Map)
                : jsonDecode(resp.data?.toString() ?? '{}')
                    as Map<String, dynamic>;
        final msg = data['error'] ?? data['message'] ?? 'Logout fallito';
        throw Exception(msg.toString());
      } catch (_) {}
    }
  }

  Future<AuthResult> refreshToken() async {
    // MUST be authenticated=false: access token may be expired/missing.
    // Refresh is done via httpOnly cookie persisted in Dio CookieJar.
    final resp = await _http.post<dynamic>(
      '/auth/refresh',
      authenticated: false,
    );

    if (resp.statusCode != 200) {
      String message = 'Refresh token fallito (${resp.statusCode})';
      if (resp.statusCode == 429) {
        message = 'Troppe richieste, riprova più tardi.';
      }
      try {
        final data =
            (resp.data is Map)
                ? Map<String, dynamic>.from(resp.data as Map)
                : jsonDecode(resp.data?.toString() ?? '{}')
                    as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data =
        (resp.data is Map)
            ? Map<String, dynamic>.from(resp.data as Map)
            : jsonDecode(resp.data?.toString() ?? '{}') as Map<String, dynamic>;
    return AuthResult.fromJson(data);
  }

  Future<AuthResult> socialLoginWithGoogle(String idToken) async {
    final resp = await _http.post<dynamic>(
      '/auth/google',
      authenticated: false,
      headers: const {'Content-Type': 'application/json'},
      data: {'idToken': idToken},
    );

    if (resp.statusCode != 200) {
      String message = 'Login Google fallito (${resp.statusCode})';
      try {
        final data =
            (resp.data is Map)
                ? Map<String, dynamic>.from(resp.data as Map)
                : jsonDecode(resp.data?.toString() ?? '{}')
                    as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data =
        (resp.data is Map)
            ? Map<String, dynamic>.from(resp.data as Map)
            : jsonDecode(resp.data?.toString() ?? '{}') as Map<String, dynamic>;
    return AuthResult.fromJson(data);
  }

  Future<AuthResult> socialLoginWithApple(String idToken) async {
    final resp = await _http.post<dynamic>(
      '/auth/apple',
      authenticated: false,
      headers: const {'Content-Type': 'application/json'},
      data: {'idToken': idToken},
    );

    if (resp.statusCode != 200) {
      String message = 'Login Apple fallito (${resp.statusCode})';
      try {
        final data =
            (resp.data is Map)
                ? Map<String, dynamic>.from(resp.data as Map)
                : jsonDecode(resp.data?.toString() ?? '{}')
                    as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data =
        (resp.data is Map)
            ? Map<String, dynamic>.from(resp.data as Map)
            : jsonDecode(resp.data?.toString() ?? '{}') as Map<String, dynamic>;
    return AuthResult.fromJson(data);
  }
}
