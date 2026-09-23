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
  ApiClient({required String baseUrl, required TokenStorage tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage,
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
  final TokenStorage _tokenStorage;

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

  Future<Map<String, dynamic>> patch(
    String path, {
    bool requiresAuth = true,
    Map<String, dynamic>? body,
  }) =>
      _request('PATCH', path, requiresAuth: requiresAuth, body: body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    required bool requiresAuth,
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    bool expectNoContent = false,
  }) async {
    final headers = <String, dynamic>{};
    if (requiresAuth) {
      final token = await _tokenStorage.readAccessToken();
      if (token == null) throw const SessionExpiredException();
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: headers),
      );
      if (expectNoContent) return const <String, dynamic>{};
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{'data': data};
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
