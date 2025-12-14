class AuthResult {
  final String accessToken;
  final String userId;
  final String email;
  final String? username;

  AuthResult({
    required this.accessToken,
    required this.userId,
    required this.email,
    this.username,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['token'] as String,
      userId: json['userId'] as String,
      email: (json['email'] as String?) ?? '',
      username: json['username'] as String?,
    );
  }
}
