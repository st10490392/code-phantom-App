import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exceptions.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utilities/startup_trace.dart';
import '../domain/auth_session.dart';
import '../domain/auth_user.dart';
import 'auth_service.dart';
import 'backend_permission_mapping.dart';

/// Real CodePhantom backend implementation of [AuthService] — see
/// `docs/ARCHITECTURE.md` §API auth for the endpoint contract this follows
/// (`POST /auth/login`, `/auth/logout`, `/auth/refresh`,
/// `/auth/password-reset/request`, `GET /me`, `POST /auth/register`,
/// `POST /auth/verification/resend`).
///
/// `register`/`resendVerificationEmail` match the backend's registration/
/// verification milestone exactly: `POST /auth/register` takes
/// `{ email, username, password, display_name }` (password minimum 12 characters,
/// enforced both client- and server-side) and always responds 202 with a
/// generic `{ data: { message } }`, even when the email is already
/// registered — the backend deliberately never reveals that distinction
/// (anti-enumeration), so this client has no special case for it either; a
/// "duplicate" registration attempt looks exactly like a fresh one and
/// still routes to the verification screen. `POST /auth/verification/resend`
/// takes `{ email }` and is equally generic. A login attempt against an
/// unverified account gets a 403 distinguished from a suspended/disabled
/// account by message text (see `dio_error_mapper.dart`'s
/// `_isEmailNotVerified`), since the backend does not yet send a separate
/// machine-readable error code for it.
///
/// Startup restoration (`restoreSession`) does exactly what the milestone
/// asks: inspect the stored session, refresh if the access token looks
/// expired, call `/me`, and build the authenticated [AuthUser] from the
/// server's own roles/permissions — never from anything computed locally.
/// Any failure along the way returns `null` (never throws) so
/// `AuthController` always lands on a clean `unauthenticated` state rather
/// than surfacing a half-restored session.
class ApiAuthService implements AuthService {
  ApiAuthService(this._client, this._tokenStorage, {String? authRedirectUrl})
      : _authRedirectUrl = authRedirectUrl ?? ApiConfig.authRedirectUrl {
    // Lets every authenticated request refresh an expiring access token
    // with the same single-flight refresh used at startup.
    _client.sessionRefresher = _refresh;
  }

  final ApiClient _client;
  final TokenStorage _tokenStorage;

  /// Platform-specific: the custom scheme on mobile, an HTTPS page on the
  /// web (see `ApiConfig.authRedirectUrl`).
  final String _authRedirectUrl;

  /// Single-flight guard: concurrent callers during a refresh all await the
  /// same in-flight request instead of each firing their own
  /// `/auth/refresh` call (and each retrying independently, which is how a
  /// refresh "loop" would start).
  Future<String>? _refreshInFlight;

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    // `password` is sent once, in this request body, over HTTPS in a real
    // deployment — never logged, never written to storage, never included
    // in any exception message this method can throw.
    final response = await _client.post(
      '/auth/login',
      requiresAuth: false,
      body: {'email': email, 'password': password},
    );
    final sessionData = response['data'] as Map<String, dynamic>;
    await _persistTokens(sessionData);
    final user = await _fetchProfile();
    return _sessionFrom(sessionData, user);
  }

  @override
  Future<void> logout() async {
    try {
      await _client.postNoContent('/auth/logout', requiresAuth: true);
    } on AppException {
      // Safe local logout path: even if the server call fails (offline,
      // already-expired token, backend down), the device still forgets
      // its credentials below.
    } finally {
      await _tokenStorage.clear();
    }
  }

  @override
  Future<AuthSession?> restoreSession() async {
    try {
      // Startup performance note: this used to read the access token twice
      // (once via `hasStoredSession()`, again inside the old
      // `_validAccessToken()` helper) and the expiry twice, all
      // sequentially — 5 secure-storage round trips before the network
      // call even started. Each is its own platform-channel call into
      // Android's Keystore-backed EncryptedSharedPreferences, which is
      // measurably slow on low-end/older hardware. This reads each key
      // exactly once, and fetches the two that are always needed together
      // (expiry + refresh token) in parallel instead of one after another.
      final accessToken = await traceStartup(
        'restoreSession: read access token',
        _tokenStorage.readAccessToken,
      );
      if (accessToken == null) return null;

      final stored = await traceStartup(
        'restoreSession: read expiry + refresh token (parallel)',
        () => Future.wait([
          _tokenStorage.readExpiresAt(),
          _tokenStorage.readRefreshToken(),
        ]),
      );
      final expiresAt = stored[0] as DateTime?;
      var refreshToken = stored[1] as String?;

      final stillValid = expiresAt != null &&
          expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 30)));

      String accessTokenToUse;
      DateTime sessionExpiresAt;
      if (stillValid) {
        accessTokenToUse = accessToken;
        sessionExpiresAt = expiresAt;
      } else {
        // Refresh persists new access/refresh/expiry values, so — unlike
        // the read above — these two must be re-read afterwards; they did
        // just change.
        accessTokenToUse = await traceStartup('restoreSession: refresh access token', _refresh);
        refreshToken = await _tokenStorage.readRefreshToken();
        sessionExpiresAt = await _tokenStorage.readExpiresAt() ??
            DateTime.now().add(const Duration(minutes: 5));
      }

      // Server-authoritative: the session is never considered restored
      // until `/me` actually answers with this user's real roles and
      // permissions — nothing above is shown as an authenticated session
      // on its own.
      final user = await traceStartup('restoreSession: GET /me', _fetchProfile);

      return AuthSession(
        user: user,
        accessToken: accessTokenToUse,
        refreshToken: refreshToken,
        expiresAt: sessionExpiresAt,
      );
    } on NetworkException {
      // Transient — the backend may just be briefly unreachable. Keep the
      // stored tokens so a later retry (app relaunch, connectivity
      // returning) can still succeed; only give up on the session, not the
      // credentials.
      return null;
    } on ServerException {
      return null;
    } on AppException {
      // AuthenticationException / SessionExpiredException / AuthorizationException:
      // the session itself is genuinely no longer valid. Clear it so the
      // login screen doesn't retry with dead credentials, and so nothing
      // downstream can mistake stale storage for a real session.
      await _tokenStorage.clear();
      return null;
    }
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _client.post(
      '/auth/password-reset/request',
      requiresAuth: false,
      body: {'email': email, 'redirect_to': _authRedirectUrl},
    );
  }

  @override
  Future<void> confirmPasswordReset({
    required String accessToken,
    required String newPassword,
  }) async {
    await _client.post(
      '/auth/password-reset/confirm',
      requiresAuth: false,
      body: {'access_token': accessToken, 'new_password': newPassword},
    );
  }

  @override
  Future<void> register({
    required String displayName,
    required String username,
    required String email,
    required String password,
  }) async {
    // `password` is sent once in this request body — never logged, never
    // written to storage. The response is intentionally never read for
    // tokens: registration requires email verification before a session
    // can exist, so this call never persists anything via `_persistTokens`,
    // regardless of what the backend response happens to contain.
    await _client.post(
      '/auth/register',
      requiresAuth: false,
      body: {
        'display_name': displayName,
        'username': username,
        'email': email,
        'password': password,
        'redirect_to': _authRedirectUrl,
      },
    );
  }

  @override
  Future<void> resendVerificationEmail({required String email}) async {
    await _client.post(
      '/auth/verification/resend',
      requiresAuth: false,
      body: {'email': email, 'redirect_to': _authRedirectUrl},
    );
  }

  Future<String> _refresh() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<String> _doRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) throw const SessionExpiredException();
    try {
      final response = await _client.post(
        '/auth/refresh',
        requiresAuth: false,
        body: {'refresh_token': refreshToken},
      );
      final sessionData = response['data'] as Map<String, dynamic>;
      await _persistTokens(sessionData);
      return sessionData['access_token'] as String;
    } on AuthenticationException {
      // A 401 here specifically means "refresh token no longer valid" —
      // reframe it as session expiry, not "wrong credentials" (there were
      // no credentials entered in this call).
      throw const SessionExpiredException();
    }
  }

  Future<AuthUser> _fetchProfile() async {
    final response = await _client.get('/me', requiresAuth: true);
    final data = response['data'] as Map<String, dynamic>;
    return authUserFromApiProfile(data);
  }

  Future<void> _persistTokens(Map<String, dynamic> sessionData) {
    return _tokenStorage.save(
      accessToken: sessionData['access_token'] as String,
      refreshToken: sessionData['refresh_token'] as String?,
      expiresAt: _parseExpiresAt(sessionData),
    );
  }

  AuthSession _sessionFrom(Map<String, dynamic> sessionData, AuthUser user) {
    return AuthSession(
      user: user,
      accessToken: sessionData['access_token'] as String,
      refreshToken: sessionData['refresh_token'] as String?,
      expiresAt: _parseExpiresAt(sessionData),
    );
  }

  DateTime _parseExpiresAt(Map<String, dynamic> sessionData) {
    final expiresAtUnixSeconds = sessionData['expires_at'] as int?;
    if (expiresAtUnixSeconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(expiresAtUnixSeconds * 1000);
    }
    final expiresInSeconds = sessionData['expires_in'] as int? ?? 3600;
    return DateTime.now().add(Duration(seconds: expiresInSeconds));
  }
}
