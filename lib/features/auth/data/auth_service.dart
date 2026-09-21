import '../domain/auth_session.dart';

/// Auth is mocked in Phase 1. A real implementation (e.g. `ApiAuthService`
/// backed by `dio`) implements the same interface — no UI changes required.
///
/// Security note: whatever replaces [MockAuthService] must never store raw
/// passwords or secrets in plain local storage. Tokens go through
/// `core/storage/secure_storage.dart`.
abstract class AuthService {
  Future<AuthSession> login({required String email, required String password});

  Future<void> logout();

  /// Attempts to restore a previously persisted session (e.g. app relaunch).
  Future<AuthSession?> restoreSession();

  Future<void> requestPasswordReset({required String email});
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => 'AuthException: $message';
}
