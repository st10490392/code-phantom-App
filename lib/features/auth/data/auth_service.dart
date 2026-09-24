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

  /// Self-service sign-up. Role/permissions are never chosen by the caller —
  /// the backend assigns the new account's role (starting this milestone,
  /// always `CLIENT` with zero entitlements) server-side.
  ///
  /// Deliberately returns nothing to persist: a new account requires email
  /// verification before it can sign in, so this must never establish a
  /// local session or store a token, even if a response happened to include
  /// one.
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  });

  /// Re-sends the verification email for an account that registered but
  /// hasn't confirmed yet. Always resolves the same way regardless of
  /// whether the email is registered/already verified, to avoid account
  /// enumeration — same convention as [requestPasswordReset].
  Future<void> resendVerificationEmail({required String email});
}

/// `MockAuthService`'s own error type, folded into the same [AppException]
/// hierarchy `ApiAuthService` throws from — so `AuthController` has one
/// catch clause that handles both mock and real auth failures identically.
final class AuthException extends AppException {
  const AuthException(super.message);
}
