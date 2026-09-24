import '../../../core/network/api_client.dart';
import '../../../core/network/app_exceptions.dart';
import '../../../core/storage/token_storage.dart';
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
/// `register`/`resendVerificationEmail` follow the same request/response
/// shape as the existing password-reset endpoints (snake_case body, a
/// generic `{ data: { message } }` success envelope, no account-existence
/// signal in the response) — the CodePhantom backend doesn't expose these
/// two routes yet as of this milestone (see the "next backend milestone"
/// note in the mobile app's own history), so this is the anticipated
/// contract the mobile client is built against, ready to activate the
/// moment the backend ships it.
///
/// Startup restoration (`restoreSession`) does exactly what the milestone
/// asks: inspect the stored session, refresh if the access token looks
/// expired, call `/me`, and build the authenticated [AuthUser] from the
/// server's own roles/permissions — never from anything computed locally.
/// Any failure along the way returns `null` (never throws) so
/// `AuthController` always lands on a clean `unauthenticated` state rather
/// than surfacing a half-restored session.
class ApiAuthService implements AuthService {
  ApiAuthService(this._client, this._tokenStorage);

  final ApiClient _client;
  final TokenStorage _tokenStorage;

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
      if (!await _tokenStorage.hasStoredSession()) return null;
      final accessToken = await _validAccessToken();
      final user = await _fetchProfile();
      final refreshToken = await _tokenStorage.readRefreshToken();
      final expiresAt = await _tokenStorage.readExpiresAt() ??
          DateTime.now().add(const Duration(minutes: 5));
      return AuthSession(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
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
      body: {'email': email},
    );
  }

  @override
  Future<void> register({
    required String displayName,
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
        'email': email,
        'password': password,
      },
    );
  }

  @override
  Future<void> resendVerificationEmail({required String email}) async {
    await _client.post(
      '/auth/verification/resend',
      requiresAuth: false,
      body: {'email': email},
    );
  }

  /// Returns a still-valid access token, refreshing first if the stored one
  /// is missing or within 30 seconds of expiry. Throws [SessionExpiredException]
  /// if there is nothing to restore or the refresh itself fails.
  Future<String> _validAccessToken() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) throw const SessionExpiredException();

    final expiresAt = await _tokenStorage.readExpiresAt();
    final stillValid =
        expiresAt != null && expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 30)));
    if (stillValid) return accessToken;

    return _refresh();
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
