import 'auth_state.dart';

class SocialLoginResult {
  final String provider;
  final String accessToken;
  final String? idToken;
  final String? email;
  final bool isNewUser;

  const SocialLoginResult({
    required this.provider,
    required this.accessToken,
    this.idToken,
    this.email,
    this.isNewUser = false,
  });
}

abstract class SocialAuthApi {
  Future<AuthSession> loginWithGoogle({required String idToken});
  Future<AuthSession> loginWithApple({required String idToken});
  Future<AuthSession> loginWithFacebook({required String accessToken});
}