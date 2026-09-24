/// Application-level errors every network-backed service throws, instead of
/// leaking `DioException`/HTTP status codes/backend stack traces to the UI.
///
/// `AuthException` (in `features/auth/data/auth_service.dart`, used only by
/// `MockAuthService`) extends this too, so `AuthController` has exactly one
/// catch clause that works for both mock and real auth.
abstract base class AppException implements Exception {
  const AppException(this.message);

  /// User-facing text — never a raw stack trace or internal detail.
  final String message;

  @override
  String toString() => message;
}

/// No usable connection to the backend (offline, DNS failure, connection
/// refused, timed out before a response arrived). Maps to the "server
/// unavailable" UI state.
final class NetworkException extends AppException {
  const NetworkException([super.message = 'Network error. Check your connection and try again.']);
}

/// The backend responded but with a 5xx, or something this client doesn't
/// know how to interpret. Also the "server unavailable" UI state.
final class ServerException extends AppException {
  const ServerException([super.message = 'Server error. Please try again later.']);
}

/// 401 on an attempt that has no session yet (login itself) — wrong
/// credentials, not an expired one.
final class AuthenticationException extends AppException {
  const AuthenticationException([super.message = 'Invalid email or password.']);
}

/// 401 on a call that expected an existing, valid session (e.g. `/me`, or a
/// refresh whose refresh token is no longer valid). Callers should clear
/// the stored session and return to the login screen.
final class SessionExpiredException extends AppException {
  const SessionExpiredException([super.message = 'Your session has expired. Please sign in again.']);
}

/// 403 — authenticated, but not authorized (missing permission/entitlement,
/// or a suspended/disabled account on login).
final class AuthorizationException extends AppException {
  const AuthorizationException([super.message = 'You do not have permission to perform this action.']);
}

/// 403 with `error.code == 'EMAIL_NOT_VERIFIED'` on a login attempt — the
/// account exists and the password is correct, but the backend requires a
/// verified email before a session can be established. Distinguished from
/// [AuthorizationException] (suspended/disabled) so the login screen can
/// route the user straight to the verification/resend flow instead of just
/// showing an error string.
final class EmailNotVerifiedException extends AppException {
  const EmailNotVerifiedException([super.message = 'Please verify your email before signing in.']);
}

/// 400 / `VALIDATION_ERROR` — malformed or rejected request body.
final class ValidationException extends AppException {
  const ValidationException(super.message, {this.details});

  /// The backend's `error.details` (e.g. zod's `flatten()` shape), if any —
  /// for callers that want field-level messages. Never shown raw to a user.
  final Map<String, dynamic>? details;
}

/// 429 / `RATE_LIMITED` — the caller has been rate-limited. Currently only
/// reachable from `POST /auth/register` and `POST /auth/verification/resend`
/// (5 requests per 15 minutes each, stacked on top of the global limiter —
/// see the backend's `publicAuthRateLimiter`), since those are the two
/// unauthenticated endpoints a script could hammer to mass-create accounts
/// or email-bomb a victim with verification resends. Distinguished from
/// [ServerException] so a caller can show "try again in a few minutes"
/// rather than implying the backend itself is broken.
final class RateLimitedException extends AppException {
  const RateLimitedException([super.message = 'Too many requests. Please try again later.']);
}
