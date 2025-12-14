import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_api_client.dart';
import 'auth_storage.dart';
import 'auth_result.dart';

final authStorageProvider = Provider<AuthStorage>((ref) {
  return const AuthStorage();
});

final authApiClientProvider = Provider<AuthApiClient>((ref) {
  // 1. Se definito nel .env, usa quello (utile per device fisici: http://192.168.x.x:3000)
  final envUrl = dotenv.env['API_URL'];
  if (envUrl != null && envUrl.isNotEmpty) {
    return AuthApiClient(envUrl);
  }

  // 2. Altrimenti usa la logica automatica per emulatori
  // - Android Emulator: 10.0.2.2
  // - iOS Simulator / macOS: 127.0.0.1
  String baseUrl = 'http://127.0.0.1:3000';
  if (Platform.isAndroid) {
    baseUrl = 'http://10.0.2.2:3000';
  }
  return AuthApiClient(baseUrl);
});

class AuthSession {
  final String accessToken;
  final String userId; // allineato a AuthResult.userId
  final String email;  // nuova proprietà email

  const AuthSession({
    required this.accessToken,
    required this.userId,
    required this.email,
  });
}

class AuthState {
  final AuthSession? session;

  const AuthState._({this.session});

  const AuthState.loggedOut() : this._();

  const AuthState.loggedIn(AuthSession session) : this._(session: session);
}

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final storage = ref.read(authStorageProvider);
    final stored = await storage.loadSession();
    if (stored == null) {
      return const AuthState.loggedOut();
    }
    return AuthState.loggedIn(
      AuthSession(
        accessToken: stored.accessToken,
        userId: stored.userId,
        email: stored.email ?? '',
      ),
    );
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final api = ref.read(authApiClientProvider);
    final storage = ref.read(authStorageProvider);

    try {
      final result = await api.login(email: email, password: password);
      await storage.saveSession(result);

      final session = AuthSession(
        accessToken: result.accessToken,
        userId: result.userId,
        email: result.email,
      );

      state = AsyncData(AuthState.loggedIn(session));
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  void setSessionFromResult(AuthResult result) {
    final session = AuthSession(
      accessToken: result.accessToken,
      userId: result.userId,
      email: result.email,
    );
    state = AsyncData(AuthState.loggedIn(session));
  }

  Future<void> logout() async {
    final api = ref.read(authApiClientProvider);
    final storage = ref.read(authStorageProvider);
    try {
      await api.logout();
    } catch (_) {}
    await storage.clearSession();
    state = const AsyncData(AuthState.loggedOut());
  }

  Future<void> loginWithGoogle(String idToken) async {
    state = const AsyncLoading();
    final api = ref.read(authApiClientProvider);
    final storage = ref.read(authStorageProvider);

    try {
      final result = await api.socialLoginWithGoogle(idToken);
      await storage.saveSession(result);
      setSessionFromResult(result);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> loginWithApple(String idToken) async {
    state = const AsyncLoading();
    final api = ref.read(authApiClientProvider);
    final storage = ref.read(authStorageProvider);

    try {
      final result = await api.socialLoginWithApple(idToken);
      await storage.saveSession(result);
      setSessionFromResult(result);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);