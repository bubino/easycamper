import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'auth_state.dart';

class ApiHttpClient {
  final String baseUrl;
  final Ref ref;
  final Dio _dio;

  static DateTime? _refreshCooldownUntil;

  ApiHttpClient({
    required this.baseUrl,
    required this.ref,
    Dio? dio,
  }) : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl));

  static const _defaultJsonHeaders = <String, String>{
    'Content-Type': 'application/json',
  };

  /// Must be called once to enable persistent cookie storage.
  /// This is critical for HttpOnly refresh token cookies.
  Future<void> ensureCookiesInitialized() async {
    // If cookie manager is already attached, do nothing.
    final already = _dio.interceptors.any((i) => i is CookieManager);
    if (already) return;

    final dir = await getApplicationSupportDirectory();
    final jar = PersistCookieJar(
      storage: FileStorage('${dir.path}/.easycamper_cookies'),
    );

    _dio.interceptors.add(CookieManager(jar));

    // Reasonable defaults
    _dio.options
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 20)
      ..sendTimeout = const Duration(seconds: 20);
  }

  bool get _isInRefreshCooldown {
    final until = _refreshCooldownUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  void _startRefreshCooldown([Duration duration = const Duration(seconds: 20)]) {
    _refreshCooldownUntil = DateTime.now().add(duration);
  }

  Future<Response<String>> get(
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

  Future<Response<String>> post(
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

  Future<Response<String>> _send(
    String method,
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
    bool authenticated = true,
  }) async {
    await ensureCookiesInitialized();

    final effectiveHeaders = <String, String>{
      ..._defaultJsonHeaders,
      ...?headers,
    };

    if (authenticated) {
      final authState = ref.read(authControllerProvider);
      final token = authState.value?.session?.accessToken;
      if (token != null && token.isNotEmpty) {
        effectiveHeaders['Authorization'] = 'Bearer $token';
      }
    }

    Response<String> response = await _execute(
      method,
      path,
      headers: effectiveHeaders,
      queryParameters: queryParameters,
      body: body,
    );

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

        response = await _execute(
          method,
          path,
          headers: effectiveHeaders,
          queryParameters: queryParameters,
          body: body,
        );
      } else {
        await ref.read(authControllerProvider.notifier).logout();
      }
    }

    return response;
  }

  Future<Response<String>> _execute(
    String method,
    String path, {
    required Map<String, String> headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) async {
    try {
      final options = Options(
        method: method,
        headers: headers,
        responseType: ResponseType.plain,
        // We handle non-2xx ourselves.
        validateStatus: (_) => true,
      );

      return await _dio.request<String>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      // Match old behavior: surface as an exception.
      throw Exception(e.message ?? 'Errore rete');
    }
  }

  bool _isAuthError(int? statusCode) {
    return statusCode == 401 || statusCode == 403;
  }

  Future<bool> _tryRefreshToken() async {
    if (_isInRefreshCooldown) {
      return false;
    }

    try {
      final storage = ref.read(authStorageProvider);
      final authApi = ref.read(authApiClientProvider);
      final refreshResult = await authApi.refreshToken();
      await storage.saveSession(refreshResult);
      final controller = ref.read(authControllerProvider.notifier);
      controller.setSessionFromResult(refreshResult);
      return true;
    } catch (e, st) {
      // Cooldown so we don't spam /auth/refresh and trigger 429
      _startRefreshCooldown();
      if (kDebugMode) {
        debugPrint('REFRESH DEBUG: errore durante /auth/refresh: $e');
        debugPrint(st.toString());
      }
      return false;
    }
  }
}

final apiHttpClientProvider = Provider<ApiHttpClient>((ref) {
  final envBaseUrl = dotenv.env['API_BASE_URL'];
  final baseUrl = (envBaseUrl != null && envBaseUrl.trim().isNotEmpty)
      ? envBaseUrl.trim()
      : 'http://127.0.0.1:3000';
  return ApiHttpClient(baseUrl: baseUrl, ref: ref);
});
