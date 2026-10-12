import 'dart:async';
import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import 'app_exceptions.dart';
import 'dio_error_mapper.dart';

/// Thin, reusable REST client for every real (`Api*Service`) service — not
/// just auth. Owns base URL, timeouts, JSON, the `Authorization: Bearer`
/// header, and DioException → [AppException] mapping so no networking code
/// (or a raw try/catch on `DioException`) ever needs to live in a widget or
/// a `Mock*`/`Api*Service`'s call sites.
///
/// Auth-header handling here is deliberately simple: it attaches whatever
/// access token is currently in [TokenStorage] and nothing more — it does
/// not check expiry or refresh on 401. That orchestration (expiry check,
/// single-flight refresh, "give up and clear session" after a failed
/// refresh) lives in `ApiAuthService`, the only real service this milestone
/// ships. A later milestone that adds a second real `Api*Service` is the
/// right time to promote refresh-on-401 into this client (e.g. as a Dio
/// interceptor) — premature here, since there is only one caller to prove
/// the design against.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStorage tokenStorage,
    Future<String?> Function()? deviceIdProvider,
    Dio? dio,
  })  : _tokenStorage = tokenStorage,
        _deviceIdProvider = deviceIdProvider,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: _timeout,
                receiveTimeout: _timeout,
                sendTimeout: _timeout,
              ),
            );

  static const _timeout = Duration(seconds: 12);

  /// Refresh this long before the stored expiry, so a request never leaves
  /// with a token that expires in flight.
  static const _refreshMargin = Duration(seconds: 30);

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final Future<String?> Function()? _deviceIdProvider;

  /// Set by `ApiAuthService`: exchanges the stored refresh token for a new
  /// access token (single-flight) or throws [SessionExpiredException].
  Future<String> Function()? sessionRefresher;

  final StreamController<void> _sessionExpired = StreamController<void>.broadcast();

  /// Fires when an authenticated request finds the session unrecoverable
  /// (refresh token rejected). The stored session has already been cleared;
  /// `AuthController` listens and returns the user to sign-in.
  Stream<void> get sessionExpired => _sessionExpired.stream;

  Future<Map<String, dynamic>> get(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? query,
  }) =>
      _request('GET', path, requiresAuth: requiresAuth, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? body,
  }) =>
      _request('POST', path, requiresAuth: requiresAuth, body: body);

  Future<void> postNoContent(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? body,
  }) async {
    await _request('POST', path, requiresAuth: requiresAuth, body: body, expectNoContent: true);
  }

  /// Explicit one-shot operation: refresh may precede sending, never replay it.
  Future<Map<String, dynamic>> postOnce(
    String path, {
    required String expectedUserId,
    required Map<String, dynamic> body,
  }) =>
      _request('POST', path, requiresAuth: true, body: body,
          retryAuthentication: false, expectedUserId: expectedUserId);

  Future<Map<String, dynamic>> patch(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? body,
  }) =>
      _request('PATCH', path, requiresAuth: requiresAuth, body: body);

  /// Diagnostics only: hits the backend's unauthenticated liveness probe at
  /// `<origin>/health` — NOT under the versioned `/api/v1` prefix every
  /// other method here uses, so it's built from the configured base URL's
  /// origin directly rather than going through `_request`. Used by the
  /// in-app diagnostics screen to prove the app can actually reach the
  /// configured backend, and to show what environment the backend itself
  /// reports (`{ status, env, version, started_at }` — see
  /// `code-phantom-backend`'s `src/modules/health/routes.ts`), independent
  /// of what this build was compiled with. Never call this for anything
  /// other than a manual connectivity check — no real service should ever
  /// depend on it.
  Future<Map<String, dynamic>> checkHealth() async {
    final base = Uri.parse(_dio.options.baseUrl);
    if (base.host.isEmpty) {
      throw const NetworkException('No backend configured for this build (mock mode).');
    }
    final healthUri = base.replace(path: '/health');
    try {
      final response = await _dio.getUri<dynamic>(healthUri);
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{'data': data};
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    required bool requiresAuth,
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    bool expectNoContent = false,
    bool retryAuthentication = true,
    String? expectedUserId,
  }) async {
    Future<Map<String, dynamic>> send(String? token) async {
      try {
        final deviceId =
            token != null && _deviceIdProvider != null
                ? await _deviceIdProvider()
                : null;
        if (expectedUserId != null &&
            await _tokenStorage.readActiveUserId() != expectedUserId) {
          throw const SessionExpiredException();
        }
        final response = await _dio.request<dynamic>(
          path,
          data: body,
          queryParameters: query,
          options: Options(
            method: method,
            headers: {
              if (token != null) 'Authorization': 'Bearer $token',
              if (deviceId != null && deviceId.isNotEmpty)
                'X-CP-Device-Id': deviceId,
            },
          ),
        );
        if (expectNoContent) return const <String, dynamic>{};
        final data = response.data;
        if (data is Map<String, dynamic>) return data;
        return <String, dynamic>{'data': data};
      } on DioException catch (e) {
        throw mapDioException(e);
      }
    }

    if (!requiresAuth) return send(null);

    var token = await _currentAccessToken();
    try {
      return await send(token);
    } on AuthenticationException {
      if (!retryAuthentication) throw const SessionExpiredException();
      // 401 on a call made with a session: the access token was rejected
      // (expired early, revoked, rotated). Refresh once and retry; this is
      // never "wrong email or password".
      if (sessionRefresher == null) throw const SessionExpiredException();
      token = await _refreshOrExpire();
      try {
        return await send(token);
      } on AuthenticationException {
        await _expire();
        throw const SessionExpiredException();
      }
    }
  }

  Future<String> _currentAccessToken() async {
    final token = await _tokenStorage.readAccessToken();
    if (token == null) throw const SessionExpiredException();
    if (sessionRefresher == null) return token;
    final expiresAt = await _tokenStorage.readExpiresAt();
    if (expiresAt != null && expiresAt.isBefore(DateTime.now().add(_refreshMargin))) {
      return _refreshOrExpire();
    }
    return token;
  }

  Future<String> _refreshOrExpire() async {
    try {
      return await sessionRefresher!();
    } on SessionExpiredException {
      await _expire();
      rethrow;
    }
  }

  Future<void> _expire() async {
    await _tokenStorage.clear();
    _sessionExpired.add(null);
  }
}
