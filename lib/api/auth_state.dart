import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'auth_api.dart';
import 'auth_storage.dart';
import 'auth_result.dart';

// Base URL per il backend di autenticazione.
// - Per simulatore iOS / emulatore Android si può usare http://127.0.0.1:3000
// - Per dispositivo fisico bisogna usare l'IP del Mac nella LAN.
//   In questo caso: http://192.168.1.3:3000
const String kAuthBaseUrl = 'http://192.168.1.3:3000';

enum AuthStatus { unknown, loggedOut, loggedIn }

class AuthSession {
  final String accessToken;
  final String userId; // UUID tecnico
  final String email;
  final String? username; // nome/username visuale

  const AuthSession({
    required this.accessToken,
    required this.userId,
    required this.email,
    this.username,
  });
}

class AuthState {
  final AuthStatus status;
  final AuthSession? session;
  final Object? error;

  const AuthState({
    required this.status,
    this.session,
    this.error,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.loggedOut() : this(status: AuthStatus.loggedOut);
  const AuthState.loggedIn(AuthSession session)
      : this(status: AuthStatus.loggedIn, session: session);

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    Object? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      error: error ?? this.error,
    );
  }
}

final authStorageProvider = Provider<AuthStorage>((ref) {
  return const AuthStorage();
});

final authApiClientProvider = Provider<AuthApiClient>((ref) {
  String? envBaseUrl;
  try {
    // Può lanciare NotInitializedError se dotenv non è stato inizializzato.
    envBaseUrl = dotenv.env['API_BASE_URL'];
  } catch (_) {
    envBaseUrl = null;
  }

  final baseUrl = (envBaseUrl != null && envBaseUrl.trim().isNotEmpty)
      ? envBaseUrl.trim()
      : kAuthBaseUrl;
  return AuthApiClient(baseUrl);
});

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
        username: stored.username,
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
        username: result.username,
      );

      state = AsyncData(AuthState.loggedIn(session));
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> logout() async {
    final api = ref.read(authApiClientProvider);
    final storage = ref.read(authStorageProvider);
    try {
      await api.logout();
    } catch (_) {
      // Non bloccare il logout client in caso di errore backend
    }
    await storage.clearSession();
    state = const AsyncData(AuthState.loggedOut());
  }

  /// Aggiorna la sessione a partire da un AuthResult (es. dopo /auth/refresh o social login).
  void setSessionFromResult(AuthResult result) {
    final session = AuthSession(
      accessToken: result.accessToken,
      userId: result.userId,
      email: result.email,
      username: result.username,
    );
    state = AsyncData(AuthState.loggedIn(session));
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

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(() {
  return AuthController();
});
