import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
  });

  final AuthUser user;
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
