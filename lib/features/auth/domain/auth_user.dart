class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.nickname = '',
  });

  final String id;
  final String email;
  final String nickname;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      nickname: (json['nickname'] as String?) ?? '',
    );
  }
}
