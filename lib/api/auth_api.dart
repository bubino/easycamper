import 'dart:convert';

import 'auth_result.dart';
import 'http_client.dart';

class AuthApiClient {
  final ApiHttpClient _http;

  const AuthApiClient(this._http);

  String get baseUrl => _http.baseUrl;

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final resp = await _http.post(
      '/auth/register',
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
      authenticated: false,
    );

    if (resp.statusCode != 201) {
      String message = 'Registrazione fallita (${resp.statusCode})';
      try {
        final data = jsonDecode(resp.data ?? '') as Map<String, dynamic>;
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
    final resp = await _http.post(
      '/auth/login',
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
      authenticated: false,
    );

    if (resp.statusCode != 200) {
      String message = 'Login fallito (${resp.statusCode})';
      try {
        final data = jsonDecode(resp.data ?? '') as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data = jsonDecode(resp.data ?? '') as Map<String, dynamic>;
    return AuthResult.fromJson(data);
  }

  Future<void> requestPasswordReset(String email) async {
    final resp = await _http.post(
      '/auth/request-reset-password',
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
      authenticated: false,
    );

    if (resp.statusCode != 200) {
      String message = 'Invio email di reset fallito (${resp.statusCode})';
      try {
        final data = jsonDecode(resp.data ?? '') as Map<String, dynamic>;
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
    final resp = await _http.post(
      '/auth/logout',
      authenticated: false,
    );
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      try {
        final data = jsonDecode(resp.data ?? '') as Map<String, dynamic>;
        final msg = data['error'] ?? data['message'] ?? 'Logout fallito';
        throw Exception(msg.toString());
      } catch (_) {}
    }
  }

  Future<AuthResult> refreshToken() async {
    // IMPORTANT: cookie HttpOnly refreshToken must be sent automatically.
    // This works because ApiHttpClient uses Dio + CookieJar.
    final resp = await _http.post(
      '/auth/refresh',
      authenticated: false,
    );

    if (resp.statusCode != 200) {
      String message = 'Refresh token fallito (${resp.statusCode})';
      if (resp.statusCode == 429) {
        message = 'Troppe richieste, riprova più tardi.';
      }
      try {
        final data = jsonDecode(resp.data ?? '') as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data = jsonDecode(resp.data ?? '') as Map<String, dynamic>;
    return AuthResult.fromJson(data);
  }

  Future<AuthResult> socialLoginWithGoogle(String idToken) async {
    final resp = await _http.post(
      '/auth/google',
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
      authenticated: false,
    );

    if (resp.statusCode != 200) {
      String message = 'Login Google fallito (${resp.statusCode})';
      try {
        final data = jsonDecode(resp.data ?? '') as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data = jsonDecode(resp.data ?? '') as Map<String, dynamic>;
    return AuthResult.fromJson(data);
  }

  Future<AuthResult> socialLoginWithApple(String idToken) async {
    final resp = await _http.post(
      '/auth/apple',
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
      authenticated: false,
    );

    if (resp.statusCode != 200) {
      String message = 'Login Apple fallito (${resp.statusCode})';
      try {
        final data = jsonDecode(resp.data ?? '') as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data = jsonDecode(resp.data ?? '') as Map<String, dynamic>;
    return AuthResult.fromJson(data);
  }
}
