class AuthResult {
  final String accessToken;
  final String userId;
  final String email;
  final String? username; // nuovo campo opzionale

  const AuthResult({
    required this.accessToken,
    required this.userId,
    required this.email,
    this.username,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    // Il backend può restituire sia `accessToken` sia `token`.
    final token = (json['accessToken'] ?? json['token']) as String?;
    final userId = json['userId'] as String?;
    final email = json['email'] as String? ?? '';
    final username = json['username'] as String?; // può mancare

    if (token == null || userId == null) {
      throw Exception('Risposta di autenticazione non valida dal server.');
    }

    return AuthResult(
      accessToken: token,
      userId: userId,
      email: email,
      username: username,
    );
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'userId': userId,
        'email': email,
        if (username != null) 'username': username,
      };
}
