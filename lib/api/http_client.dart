import 'dart:async';

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'auth_state.dart';

class ApiHttpClient {
  final String baseUrl;
  final Ref ref;

  late final Dio _dio;
  late final CookieJar _cookieJar;

  static DateTime? _refreshCooldownUntil;
  static Future<bool>? _refreshInFlight;

  ApiHttpClient({
    required this.baseUrl,
    required this.ref,
    Dio? dio,
    CookieJar? cookieJar,
  }) {
    _cookieJar = cookieJar ?? CookieJar();
    _dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 20),
            // IMPORTANT: cookies are handled by CookieManager.
            headers: const {'Accept': 'application/json'},
            // We'll handle errors manually to decide if/when to refresh.
            validateStatus: (code) => code != null && code >= 100 && code < 600,
          ),
        );

    _dio.interceptors.add(CookieManager(_cookieJar));

    // Attach access token to outgoing requests.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final authenticated = options.extra['authenticated'] != false;
          if (authenticated) {
            final authState = ref.read(authControllerProvider);
            final token = authState.value?.session?.accessToken;
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            } else {
              options.headers.remove('Authorization');
              if (kDebugMode) {
                debugPrint(
                  'HTTP DEBUG: missing accessToken for ${options.method} ${options.uri} (authState=${authState.value?.status})',
                );
              }
            }
          } else {
            options.headers.remove('Authorization');
          }

          // Ensure JSON default when body is Map
          options.headers.putIfAbsent('Content-Type', () => 'application/json');

          handler.next(options);
        },
      ),
    );

    // Refresh & retry on 401/403.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException err, handler) async {
          // Network error -> do not refresh.
          final response = err.response;
          final statusCode = response?.statusCode;
          final req = err.requestOptions;

          final authenticated = req.extra['authenticated'] != false;
          final alreadyRetried = req.extra['retried'] == true;

          if (!authenticated || alreadyRetried || statusCode == null) {
            handler.next(err);
            return;
          }

          if (!_isAuthError(statusCode)) {
            handler.next(err);
            return;
          }

          // Avoid recursive refresh
          if (req.path.endsWith('/auth/refresh')) {
            handler.next(err);
            return;
          }

          final ok = await _tryRefreshToken();
          if (!ok) {
            await ref.read(authControllerProvider.notifier).logout();
            handler.next(err);
            return;
          }

          try {
            final retryOptions = _cloneRequestOptions(req);
            retryOptions.extra['retried'] = true;

            // Set updated Authorization header
            final newAuthState = ref.read(authControllerProvider);
            final newToken = newAuthState.value?.session?.accessToken;
            if (newToken != null && newToken.isNotEmpty) {
              retryOptions.headers['Authorization'] = 'Bearer $newToken';
            } else {
              retryOptions.headers.remove('Authorization');
            }

            final retryResponse = await _dio.fetch<dynamic>(retryOptions);
            handler.resolve(retryResponse);
          } catch (e) {
            handler.next(err);
          }
        },
      ),
    );
  }

  bool get _isInRefreshCooldown {
    final until = _refreshCooldownUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  void _startRefreshCooldown([
    Duration duration = const Duration(seconds: 20),
  ]) {
    _refreshCooldownUntil = DateTime.now().add(duration);
  }

  bool _isAuthError(int statusCode) => statusCode == 401 || statusCode == 403;

  RequestOptions _cloneRequestOptions(RequestOptions o) {
    return RequestOptions(
      path: o.path,
      method: o.method,
      baseUrl: o.baseUrl,
      headers: Map<String, dynamic>.from(o.headers),
      queryParameters: Map<String, dynamic>.from(o.queryParameters),
      data: o.data,
      connectTimeout: o.connectTimeout,
      sendTimeout: o.sendTimeout,
      receiveTimeout: o.receiveTimeout,
      responseType: o.responseType,
      contentType: o.contentType,
      validateStatus: o.validateStatus,
      receiveDataWhenStatusError: o.receiveDataWhenStatusError,
      followRedirects: o.followRedirects,
      maxRedirects: o.maxRedirects,
      requestEncoder: o.requestEncoder,
      responseDecoder: o.responseDecoder,
      listFormat: o.listFormat,
      extra: Map<String, dynamic>.from(o.extra),
    );
  }

  /// Generic request
  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? headers,
    bool authenticated = true,
    ResponseType? responseType,
  }) {
    return _dio.request<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(
        method: method,
        headers: headers,
        responseType: responseType,
        extra: {'authenticated': authenticated},
      ),
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    bool authenticated = true,
    ResponseType? responseType,
  }) {
    return request<T>(
      path,
      method: 'GET',
      queryParameters: queryParameters,
      headers: headers,
      authenticated: authenticated,
      responseType: responseType,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    bool authenticated = true,
    ResponseType? responseType,
  }) {
    return request<T>(
      path,
      method: 'POST',
      data: data,
      headers: headers,
      authenticated: authenticated,
      responseType: responseType,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    bool authenticated = true,
    ResponseType? responseType,
  }) {
    return request<T>(
      path,
      method: 'PUT',
      data: data,
      headers: headers,
      authenticated: authenticated,
      responseType: responseType,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    bool authenticated = true,
    ResponseType? responseType,
  }) {
    return request<T>(
      path,
      method: 'DELETE',
      data: data,
      headers: headers,
      authenticated: authenticated,
      responseType: responseType,
    );
  }

  Future<bool> _tryRefreshToken() async {
    if (_isInRefreshCooldown) return false;

    // single-flight: if multiple requests 401 together, do one refresh.
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final completer = Completer<bool>();
    _refreshInFlight = completer.future;

    try {
      final authApi = ref.read(authApiClientProvider);
      final storage = ref.read(authStorageProvider);

      final refreshResult = await authApi.refreshToken();
      await storage.saveSession(refreshResult);
      ref
          .read(authControllerProvider.notifier)
          .setSessionFromResult(refreshResult);

      completer.complete(true);
      return true;
    } catch (e, st) {
      _startRefreshCooldown();
      if (kDebugMode) {
        debugPrint('REFRESH DEBUG: errore durante /auth/refresh: $e');
        debugPrint(st.toString());
      }
      completer.complete(false);
      return false;
    } finally {
      _refreshInFlight = null;
    }
  }
}

final apiHttpClientProvider = Provider<ApiHttpClient>((ref) {
  String? envBaseUrl;
  try {
    envBaseUrl = dotenv.env['API_BASE_URL'];
  } catch (_) {
    envBaseUrl = null;
  }

  final baseUrl =
      (envBaseUrl != null && envBaseUrl.trim().isNotEmpty)
          ? envBaseUrl.trim()
          : kAuthBaseUrl;

  return ApiHttpClient(baseUrl: baseUrl, ref: ref);
});
