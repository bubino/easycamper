import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_result.dart';

class StoredAuthSession {
  final String accessToken;
  final String userId;
  final String? email;
  final String? username; // nuovo

  const StoredAuthSession({
    required this.accessToken,
    required this.userId,
    this.email,
    this.username,
  });

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'userId': userId,
        if (email != null) 'email': email,
        if (username != null) 'username': username,
      };

  factory StoredAuthSession.fromJson(Map<String, dynamic> json) {
    return StoredAuthSession(
      accessToken: json['accessToken'] as String,
      userId: json['userId'] as String,
      email: json['email'] as String?,
      username: json['username'] as String?,
    );
  }
}

class AuthStorage {
  static const _keySession = 'auth_session_v1';
  static const _sessionLifespanMinutes = 12; // durata massima login lato client

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  const AuthStorage();

  bool get _useSecureStorage {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS || Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveSession(AuthResult result) async {
    final expiresAt = DateTime.now()
        .add(const Duration(minutes: _sessionLifespanMinutes))
        .toIso8601String();

    final stored = StoredAuthSession(
      accessToken: result.accessToken,
      userId: result.userId,
      email: result.email,
      username: result.username,
    );
    final payload = {
      ...stored.toJson(),
      'expiresAt': expiresAt,
    };
    final json = jsonEncode(payload);

    if (_useSecureStorage) {
      await _secureStorage.write(key: _keySession, value: json);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySession, json);
    }
  }

  Future<StoredAuthSession?> loadSession() async {
    String? raw;
    if (_useSecureStorage) {
      raw = await _secureStorage.read(key: _keySession);
    } else {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_keySession);
    }
    if (raw == null) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String?;
      final userId = data['userId'] as String?;
      final email = data['email'] as String?;
      final username = data['username'] as String?;
      final expiresAtRaw = data['expiresAt'] as String?;

      if (accessToken == null || userId == null || expiresAtRaw == null) {
        await clearSession();
        return null;
      }

      final expiresAt = DateTime.tryParse(expiresAtRaw);
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        await clearSession();
        return null;
      }

      return StoredAuthSession(
        accessToken: accessToken,
        userId: userId,
        email: email,
        username: username,
      );
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() async {
    if (_useSecureStorage) {
      await _secureStorage.delete(key: _keySession);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySession);
    }
  }
}
