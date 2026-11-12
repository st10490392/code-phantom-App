import 'package:dio/dio.dart';
import 'app_exceptions.dart';
import 'dio_error_mapper.dart';

/// Transport for the live trading bridge (`api_server.py`), which is a
/// different service from the primary API and speaks a different contract:
/// responses are bare JSON objects (no `{ data: … }` envelope) and failures
/// are FastAPI's `{ detail: … }`. Keeping this separate from `ApiClient` is
/// deliberate — one envelope-mapping cannot serve both shapes without either
/// target silently mis-read, and the bridge has no user session to refresh.
///
/// Reads are unauthenticated (the bridge exposes no order capability). The
/// one write this client can make — `POST /control/toggle` — requires the
/// bridge's own `scope=control` JWT, which the bridge never issues to a phone,
/// so [controlToken] is only ever supplied by an operator-side build and is
/// never read from [TokenStorage] (a Supabase session JWT is not a control
/// token; presenting it would be a fabricated authorization).
class BridgeClient {
  BridgeClient({required String baseUrl, Dio? dio, String? controlToken})
      : _controlToken = controlToken,
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

  final Dio _dio;
  final String? _controlToken;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    return _send('GET', path, query: query);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    return _send('POST', path, body: body, requiresControlToken: true);
  }

  /// Diagnostics only: the bridge's liveness/readiness projection
  /// (`GET /api/v1/status`), which is what actually proves the daemon is
  /// reachable and whether MT5 is connected.
  Future<Map<String, dynamic>> checkHealth() => _send('GET', '/status');

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    bool requiresControlToken = false,
  }) async {
    final headers = <String, String>{};
    if (requiresControlToken) {
      if (_controlToken == null) {
        throw const AuthorizationException(
          'This build has no trading-control credential; the bridge only accepts its own control token.',
        );
      }
      headers['Authorization'] = 'Bearer $_controlToken';
    }
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: headers),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{'data': data};
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  /// FastAPI reports failures as `{ detail: … }`, and for a licence-key
  /// rejection the bridge raises `HTTPException(detail: str)` carrying
  /// `license_manager`'s own message — surfaced verbatim because it is a
  /// user-facing reason ("key is expired", "hardware binding mismatch"), not
  /// a stack trace.
  AppException _map(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.badCertificate) {
      return const NetworkException('The trading bridge is unreachable. Check the connection and try again.');
    }
    final mapped = mapDioException(error);
    final detail = error.response?.data is Map ? (error.response!.data as Map)['detail'] : null;
    if (detail is! String || detail.isEmpty) return mapped;
    // The bridge's `detail` is a user-facing reason ("key is expired",
    // "hardware binding mismatch"), so it replaces the generic message while
    // the exception's kind — and therefore the UI state — stays the same.
    if (mapped is AuthenticationException) return AuthenticationException(detail);
    if (mapped is AuthorizationException) return AuthorizationException(detail);
    if (mapped is ValidationException) return ValidationException(detail);
    if (mapped is ServerException) return ServerException(detail);
    if (mapped is NetworkException) return NetworkException(detail);
    if (mapped is RateLimitedException) return RateLimitedException(detail);
    return mapped;
  }
}
