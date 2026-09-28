import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/network/api_client.dart';
import 'package:code_phantom_app/core/network/app_exceptions.dart';
import 'package:code_phantom_app/core/storage/token_storage.dart';
import '../../features/auth/fake_http_client_adapter.dart';
import '../../features/auth/fake_secure_storage.dart';

void main() {
  group('ApiClient.checkHealth', () {
    test('a successful probe returns the backend\'s env/version/status', () async {
      final tokenStorage = TokenStorage(FakeSecureStorage());
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
      Uri? requestedUri;
      dio.httpClientAdapter = FakeHttpClientAdapter((options) {
        requestedUri = options.uri;
        return const FakeResponse(
          statusCode: 200,
          body: {
            'status': 'ok',
            'env': 'staging',
            'version': '1.4.2',
            'started_at': '2026-09-01T00:00:00Z',
          },
        );
      });
      final client = ApiClient(baseUrl: 'http://test.local/api/v1', tokenStorage: tokenStorage, dio: dio);

      final result = await client.checkHealth();

      expect(requestedUri.toString(), 'http://test.local/health',
          reason: 'the probe must hit the bare host, not the /api/v1-prefixed path',);
      expect(result['status'], 'ok');
      expect(result['env'], 'staging');
      expect(result['version'], '1.4.2');
    });

    test('a network failure surfaces as NetworkException, not a raw exception', () async {
      final tokenStorage = TokenStorage(FakeSecureStorage());
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
      dio.httpClientAdapter = FakeHttpClientAdapter((_) => const FakeResponse.networkFailure());
      final client = ApiClient(baseUrl: 'http://test.local/api/v1', tokenStorage: tokenStorage, dio: dio);

      await expectLater(client.checkHealth(), throwsA(isA<NetworkException>()));
    });

    test('a 500 from the backend surfaces as ServerException', () async {
      final tokenStorage = TokenStorage(FakeSecureStorage());
      final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
      dio.httpClientAdapter = FakeHttpClientAdapter(
        (_) => const FakeResponse(
          statusCode: 500,
          body: {
            'error': {'code': 'INTERNAL_ERROR', 'message': 'Internal server error.'},
          },
        ),
      );
      final client = ApiClient(baseUrl: 'http://test.local/api/v1', tokenStorage: tokenStorage, dio: dio);

      await expectLater(client.checkHealth(), throwsA(isA<ServerException>()));
    });

    test('mock mode (empty base URL) refuses to probe rather than making a bogus request',
        () async {
      final tokenStorage = TokenStorage(FakeSecureStorage());
      final client = ApiClient(baseUrl: '', tokenStorage: tokenStorage);

      await expectLater(client.checkHealth(), throwsA(isA<NetworkException>()));
    });
  });
}
