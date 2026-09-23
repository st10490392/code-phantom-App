import '../../../core/network/app_exceptions.dart';
import '../domain/auth_session.dart';

/// `MockAuthService` (Phase 1) and `ApiAuthService` (real CodePhantom
/// backend, starting this milestone) both implement this — swapping which
/// one `authServiceProvider` resolves to (see `appEnvironmentProvider` in
/// `auth_providers.dart`) is the only thing that changes; no UI code
/// depends on which is active.
///
/// Security note: an implementation must never store raw passwords or
/// backend secrets in plain local storage. Tokens go through
/// `core/storage/token_storage.dart` (`flutter_secure_storage`-backed).
abstract class AuthService {
  Future<AuthSession> login({required String email, required String password});

  Future<void> logout();

  /// Attempts to restore a previously persisted session (e.g. app relaunch).
  Future<AuthSession?> restoreSession();

  Future<void> requestPasswordReset({required String email});
}

/// `MockAuthService`'s own error type, folded into the same [AppException]
/// hierarchy `ApiAuthService` throws from — so `AuthController` has one
/// catch clause that handles both mock and real auth failures identically.
final class AuthException extends AppException {
  const AuthException(super.message);
}
