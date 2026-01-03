import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_result.dart';

class AuthApiClient {
  final String baseUrl;

  const AuthApiClient(this.baseUrl);

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (resp.statusCode != 201) {
      String message = 'Registrazione fallita (${resp.statusCode})';
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
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
    final uri = Uri.parse('$baseUrl/auth/login');
    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (resp.statusCode != 200) {
      String message = 'Login fallito (${resp.statusCode})';
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return AuthResult.fromJson(data);
  }

  Future<void> requestPasswordReset(String email) async {
    final uri = Uri.parse('$baseUrl/auth/request-reset-password');
    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (resp.statusCode != 200) {
      String message = 'Invio email di reset fallito (${resp.statusCode})';
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
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
    final uri = Uri.parse('$baseUrl/auth/logout');
    final resp = await http.post(uri);
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final msg = data['error'] ?? data['message'] ?? 'Logout fallito';
        throw Exception(msg.toString());
      } catch (_) {}
    }
  }

  Future<AuthResult> refreshToken() async {
    final uri = Uri.parse('$baseUrl/auth/refresh');
    final resp = await http.post(uri);

    if (resp.statusCode != 200) {
      String message = 'Refresh token fallito (${resp.statusCode})';
      if (resp.statusCode == 429) {
        message = 'Troppe richieste, riprova più tardi.';
      }
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    // L'endpoint /auth/refresh restituisce { token: '...', ... }
    final token = data['token'] as String?;
    if (token == null) {
      throw Exception('Risposta refresh non valida: token mancante');
    }

    // Manteniamo userId precedente se possibile (per ora placeholder) e email vuota
    return AuthResult(
      accessToken: token,
      userId: 'unknown',
      email: '',
    );
  }

  Future<AuthResult> socialLoginWithGoogle(String idToken) async {
    final uri = Uri.parse('$baseUrl/auth/google');
    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    if (resp.statusCode != 200) {
      String message = 'Login Google fallito (${resp.statusCode})';
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return AuthResult.fromJson(data);
  }

  Future<AuthResult> socialLoginWithApple(String idToken) async {
    final uri = Uri.parse('$baseUrl/auth/apple');
    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    if (resp.statusCode != 200) {
      String message = 'Login Apple fallito (${resp.statusCode})';
      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['error'] is String) {
          message = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return AuthResult.fromJson(data);
  }
}
