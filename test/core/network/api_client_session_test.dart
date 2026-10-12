import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/config/app_environment.dart';
import 'package:code_phantom_app/core/network/api_client.dart';
import 'package:code_phantom_app/core/network/app_exceptions.dart';
import 'package:code_phantom_app/core/storage/token_storage.dart';
import 'package:code_phantom_app/features/auth/data/api_auth_service.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import '../../features/auth/fake_http_client_adapter.dart';
import '../../features/auth/fake_secure_storage.dart';

/// Access-token lifecycle during use (not only at startup): a browser tab or
/// installed PWA stays open far longer than one access token lives.
void main() {
  late TokenStorage storage;
  late List<RequestOptions> requests;
  late FakeResponse Function(RequestOptions) route;
  late ApiClient client;

  Map<String, dynamic> session(String access) => {
        'access_token': access,
        'refresh_token': 'refresh-$access',
        'expires_at': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        'expires_in': 3600,
      };

  setUp(() async {
    storage = TokenStorage(FakeSecureStorage());
    requests = [];
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
    dio.httpClientAdapter = FakeHttpClientAdapter((o) {
      requests.add(o);
      return route(o);
    });
    client = ApiClient(baseUrl: 'http://test.local/api/v1', tokenStorage: storage, dio: dio);
    ApiAuthService(client, storage, authRedirectUrl: 'https://web.example/auth/callback');
  });

  String? authOf(RequestOptions o) => o.headers['Authorization'] as String?;

  test('bound device id is attached only to authenticated requests', () async {
    await storage.save(
      accessToken: 'active',
      refreshToken: 'refresh-active',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
    dio.httpClientAdapter = FakeHttpClientAdapter((o) {
      requests.add(o);
      return const FakeResponse(statusCode: 200, body: {'data': []});
    });
    final boundClient = ApiClient(
      baseUrl: 'http://test.local/api/v1',
      tokenStorage: storage,
      deviceIdProvider: () async => '11111111-1111-4111-8111-111111111111',
      dio: dio,
    );

    for (final path in ['/scanner/setups', '/signals', '/enkidu-shadow/observations']) {
      await boundClient.get(path);
      expect(requests.last.headers['Authorization'], 'Bearer active');
      expect(
        requests.last.headers['X-CP-Device-Id'],
        '11111111-1111-4111-8111-111111111111',
      );
    }

    requests.clear();
    await boundClient.get('/public/plans', requiresAuth: false);
    expect(requests.last.headers.containsKey('X-CP-Device-Id'), isFalse);
  });

  test('an access token about to expire is refreshed before the request is sent', () async {
    await storage.save(
      accessToken: 'old',
      refreshToken: 'refresh-old',
      expiresAt: DateTime.now().add(const Duration(seconds: 5)),
    );
    route = (o) => o.path == '/auth/refresh'
        ? FakeResponse(statusCode: 200, body: {'data': session('new')})
        : const FakeResponse(statusCode: 200, body: {'data': []});
    await client.get('/signals');
    expect(requests.map((r) => r.path), ['/auth/refresh', '/signals']);
    expect(requests.first.data, {'refresh_token': 'refresh-old'});
    expect(authOf(requests.last), 'Bearer new');
    expect(await storage.readAccessToken(), 'new');
  });

  test('a 401 during use refreshes once and retries with the new token', () async {
    await storage.save(accessToken: 'revoked', refreshToken: 'refresh-revoked', expiresAt: DateTime.now().add(const Duration(hours: 1)));
    route = (o) {
      if (o.path == '/auth/refresh') return FakeResponse(statusCode: 200, body: {'data': session('fresh')});
      return authOf(o) == 'Bearer fresh'
          ? const FakeResponse(statusCode: 200, body: {'data': []})
          : const FakeResponse(statusCode: 401, body: {'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid or expired session.'}});
    };
    await client.get('/scanner/setups');
    expect(requests.map((r) => r.path), ['/scanner/setups', '/auth/refresh', '/scanner/setups']);
    expect(authOf(requests.last), 'Bearer fresh');
  });

  test('concurrent 401s share a single refresh', () async {
    await storage.save(accessToken: 'revoked', refreshToken: 'r', expiresAt: DateTime.now().add(const Duration(hours: 1)));
    route = (o) {
      if (o.path == '/auth/refresh') return FakeResponse(statusCode: 200, body: {'data': session('fresh')});
      return authOf(o) == 'Bearer fresh'
          ? const FakeResponse(statusCode: 200, body: {'data': []})
          : const FakeResponse(statusCode: 401, body: {'error': {'code': 'UNAUTHORIZED'}});
    };
    await Future.wait([client.get('/signals'), client.get('/scanner/setups'), client.get('/ea/accounts')]);
    expect(requests.where((r) => r.path == '/auth/refresh'), hasLength(1));
  });

  test('a rejected refresh token ends the session: storage cleared, expiry signalled, never "wrong password"', () async {
    await storage.save(accessToken: 'revoked', refreshToken: 'dead', expiresAt: DateTime.now().add(const Duration(hours: 1)));
    route = (o) => const FakeResponse(statusCode: 401, body: {'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid email or password.'}});
    var expired = 0;
    final sub = client.sessionExpired.listen((_) => expired++);
    await expectLater(client.get('/signals'), throwsA(isA<SessionExpiredException>()));
    await Future<void>.delayed(Duration.zero);
    expect(expired, 1);
    expect(await storage.readAccessToken(), isNull);
    expect(await storage.readRefreshToken(), isNull);
    await sub.cancel();
  });

  test('login, register and reset calls are never retried or refreshed', () async {
    route = (o) => const FakeResponse(statusCode: 401, body: {'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid email or password.'}});
    await expectLater(
      client.post('/auth/login', requiresAuth: false, body: {'email': 'a@b.c', 'password': 'x'}),
      throwsA(isA<AuthenticationException>()),
    );
    expect(requests, hasLength(1));
  });

  test('the signed-in app returns to sign-in when the session expires mid-use', () async {
    await storage.save(accessToken: 'a', refreshToken: 'r', expiresAt: DateTime.now().add(const Duration(hours: 1)));
    route = (o) => switch (o.path) {
          '/me' => const FakeResponse(statusCode: 200, body: {
              'data': {
                'profile': {'id': 'u1', 'email': 'owner@codephantom.dev', 'display_name': 'Owner', 'status': 'ACTIVE'},
                'roles': ['OWNER'],
                'permissions': ['scanner.view'],
              },
            },),
          _ => const FakeResponse(statusCode: 401, body: {'error': {'code': 'UNAUTHORIZED'}}),
        };
    final container = ProviderContainer(overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.production),
      apiClientProvider.overrideWithValue(client),
      tokenStorageProvider.overrideWithValue(storage),
    ],);
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(authControllerProvider).status, AuthStatus.authenticated);

    await expectLater(client.get('/signals'), throwsA(isA<SessionExpiredException>()));
    await Future<void>.delayed(Duration.zero);
    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.unauthenticated);
    expect(state.errorMessage, contains('session has expired'));
  });
}
