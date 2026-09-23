import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/network/api_client.dart';
import 'package:code_phantom_app/core/network/app_exceptions.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission.dart';
import 'package:code_phantom_app/core/storage/token_storage.dart';
import 'package:code_phantom_app/features/auth/data/api_auth_service.dart';
import 'fake_http_client_adapter.dart';
import 'fake_secure_storage.dart';

/// The 15 permission codes the real backend assigns OWNER (verified
/// manually against the hosted Supabase backend per the milestone brief).
const _ownerPermissionCodes = [
  'scanner.view', 'scanner.review', 'scanner.ingest',
  'signals.view', 'signals.manage', 'signals.publish',
  'ea.view', 'ea.control',
  'clients.view', 'clients.manage',
  'licences.view', 'licences.manage',
  'notifications.view', 'notifications.manage',
  'admin.system',
];

Map<String, dynamic> _sessionBody({String accessToken = 'access-1', String? refreshToken = 'refresh-1'}) {
  return {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': {'id': 'user-owner-uuid', 'email': 'owner@codephantom.dev'},
  };
}

Map<String, dynamic> _meBody({
  List<String> roles = const ['OWNER'],
  List<String> permissions = _ownerPermissionCodes,
  bool protectedProfile = true,
}) {
  return {
    'profile': {
      'id': 'user-owner-uuid',
      'email': 'owner@codephantom.dev',
      'display_name': 'Ripfumelo',
      'status': 'ACTIVE',
      'protected': protectedProfile,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    },
    'roles': roles,
    'permissions': permissions,
  };
}

typedef _Route = FakeResponse Function(RequestOptions options);

({ApiAuthService service, TokenStorage tokenStorage, void Function(String, String, _Route) mock})
    _build() {
  final tokenStorage = TokenStorage(FakeSecureStorage());
  final routes = <String, _Route>{};

  void mock(String method, String path, _Route route) {
    routes['$method $path'] = route;
  }

  final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
  dio.httpClientAdapter = FakeHttpClientAdapter((options) {
    final key = '${options.method} ${options.path}';
    final route = routes[key];
    if (route == null) {
      throw StateError('No fake route registered for $key');
    }
    return route(options);
  });

  final client = ApiClient(baseUrl: 'http://test.local/api/v1', tokenStorage: tokenStorage, dio: dio);
  final service = ApiAuthService(client, tokenStorage);
  return (service: service, tokenStorage: tokenStorage, mock: mock);
}

void main() {
  group('ApiAuthService.login', () {
    test('successful login returns a session with a server-mapped profile', () async {
      final b = _build();
      b.mock('POST', '/auth/login', (_) => FakeResponse(statusCode: 200, body: {'data': _sessionBody()}));
      b.mock('GET', '/me', (_) => FakeResponse(statusCode: 200, body: {'data': _meBody()}));

      final session = await b.service.login(email: 'owner@codephantom.dev', password: 'correct-horse');

      expect(session.accessToken, 'access-1');
      expect(session.refreshToken, 'refresh-1');
      expect(session.user.displayName, 'Ripfumelo');
      expect(session.user.role, AppRole.owner);
      expect(session.user.isOwner, isTrue);
      expect(session.user.protected, isTrue);
      expect(session.user.status, 'ACTIVE');
    });

    test('invalid credentials throw AuthenticationException', () async {
      final b = _build();
      b.mock(
        'POST',
        '/auth/login',
        (_) => const FakeResponse(
          statusCode: 401,
          body: {
            'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid email or password.'},
          },
        ),
      );

      await expectLater(
        b.service.login(email: 'owner@codephantom.dev', password: 'wrong'),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('a suspended account (403) surfaces as AuthorizationException', () async {
      final b = _build();
      b.mock(
        'POST',
        '/auth/login',
        (_) => const FakeResponse(
          statusCode: 403,
          body: {
            'error': {'code': 'FORBIDDEN', 'message': 'This account has been suspended or disabled.'},
          },
        ),
      );

      await expectLater(
        b.service.login(email: 'owner@codephantom.dev', password: 'correct-horse'),
        throwsA(isA<AuthorizationException>()),
      );
    });

    test('a network failure throws NetworkException', () async {
      final b = _build();
      b.mock('POST', '/auth/login', (_) => const FakeResponse.networkFailure());

      await expectLater(
        b.service.login(email: 'owner@codephantom.dev', password: 'correct-horse'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a successful login persists the session for later restoration', () async {
      final b = _build();
      b.mock('POST', '/auth/login', (_) => FakeResponse(statusCode: 200, body: {'data': _sessionBody()}));
      b.mock('GET', '/me', (_) => FakeResponse(statusCode: 200, body: {'data': _meBody()}));

      await b.service.login(email: 'owner@codephantom.dev', password: 'correct-horse');

      expect(await b.tokenStorage.readAccessToken(), 'access-1');
      expect(await b.tokenStorage.readRefreshToken(), 'refresh-1');
      expect(await b.tokenStorage.readExpiresAt(), isNotNull);
      expect(await b.tokenStorage.hasStoredSession(), isTrue);
    });
  });

  group('ApiAuthService.restoreSession', () {
    test('with no stored session, resolves to null without any network call', () async {
      final b = _build();
      final session = await b.service.restoreSession();
      expect(session, isNull);
    });

    test('a still-valid stored session restores via /me directly (no refresh call)', () async {
      final b = _build();
      await b.tokenStorage.save(
        accessToken: 'still-valid-token',
        refreshToken: 'refresh-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      var refreshCalled = false;
      b.mock('POST', '/auth/refresh', (_) {
        refreshCalled = true;
        return FakeResponse(statusCode: 200, body: {'data': _sessionBody()});
      });
      b.mock('GET', '/me', (_) => FakeResponse(statusCode: 200, body: {'data': _meBody()}));

      final session = await b.service.restoreSession();

      expect(session, isNotNull);
      expect(session!.user.role, AppRole.owner);
      expect(refreshCalled, isFalse);
    });

    test('an expired access token triggers a refresh, then /me, and succeeds', () async {
      final b = _build();
      await b.tokenStorage.save(
        accessToken: 'expired-token',
        refreshToken: 'refresh-1',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      b.mock(
        'POST',
        '/auth/refresh',
        (_) => FakeResponse(
          statusCode: 200,
          body: {'data': _sessionBody(accessToken: 'refreshed-token', refreshToken: 'refreshed-refresh')},
        ),
      );
      b.mock('GET', '/me', (_) => FakeResponse(statusCode: 200, body: {'data': _meBody()}));

      final session = await b.service.restoreSession();

      expect(session, isNotNull);
      expect(session!.accessToken, 'refreshed-token');
      expect(await b.tokenStorage.readAccessToken(), 'refreshed-token');
      expect(await b.tokenStorage.readRefreshToken(), 'refreshed-refresh');
    });

    test('refresh failure clears the stored session and restores to null', () async {
      final b = _build();
      await b.tokenStorage.save(
        accessToken: 'expired-token',
        refreshToken: 'dead-refresh-token',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      b.mock(
        'POST',
        '/auth/refresh',
        (_) => const FakeResponse(
          statusCode: 401,
          body: {
            'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid or expired refresh token.'},
          },
        ),
      );

      final session = await b.service.restoreSession();

      expect(session, isNull);
      expect(await b.tokenStorage.hasStoredSession(), isFalse,
          reason: 'a genuinely invalid session must be cleared, not left dangling',);
    });

    test('a network failure during restore keeps the stored tokens for a later retry', () async {
      final b = _build();
      await b.tokenStorage.save(
        accessToken: 'still-valid-token',
        refreshToken: 'refresh-1',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      b.mock('GET', '/me', (_) => const FakeResponse.networkFailure());

      final session = await b.service.restoreSession();

      expect(session, isNull);
      expect(await b.tokenStorage.hasStoredSession(), isTrue,
          reason: 'transient network failure must not wipe a possibly-still-valid session',);
    });
  });

  group('ApiAuthService.logout', () {
    test('a successful server logout clears the stored session', () async {
      final b = _build();
      await b.tokenStorage.save(
        accessToken: 'token', refreshToken: 'refresh', expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      b.mock('POST', '/auth/logout', (_) => const FakeResponse(statusCode: 204));

      await b.service.logout();

      expect(await b.tokenStorage.hasStoredSession(), isFalse);
    });

    test('a failed server logout still clears local credentials (safe local logout)', () async {
      final b = _build();
      await b.tokenStorage.save(
        accessToken: 'token', refreshToken: 'refresh', expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      b.mock('POST', '/auth/logout', (_) => const FakeResponse.networkFailure());

      await b.service.logout();

      expect(await b.tokenStorage.hasStoredSession(), isFalse);
    });
  });

  group('/me profile mapping', () {
    test('maps profile + roles + permissions into AuthUser', () async {
      final b = _build();
      b.mock('POST', '/auth/login', (_) => FakeResponse(statusCode: 200, body: {'data': _sessionBody()}));
      b.mock(
        'GET',
        '/me',
        (_) => FakeResponse(
          statusCode: 200,
          body: {
            'data': _meBody(
              roles: const ['SCANNER_CLIENT'],
              permissions: const ['scanner.view', 'notifications.view'],
              protectedProfile: false,
            ),
          },
        ),
      );

      final session = await b.service.login(email: 'x@y.com', password: 'pw');

      expect(session.user.role, AppRole.scannerClient);
      expect(session.user.protected, isFalse);
      expect(session.user.permissions.has(Permission.scannerAccess), isTrue);
      expect(session.user.permissions.has(Permission.scannerReview), isFalse);
      expect(session.user.permissions.has(Permission.clientAdmin), isFalse);
    });
  });
}
