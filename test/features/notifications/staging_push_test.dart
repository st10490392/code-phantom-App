import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/config/app_environment.dart';
import 'package:code_phantom_app/core/network/api_client.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission_set.dart';
import 'package:code_phantom_app/core/storage/token_storage.dart';
import 'package:code_phantom_app/features/auth/domain/auth_user.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/notifications/push/staging_push_test.dart';
import 'package:code_phantom_app/features/notifications/push/phone_alert.dart';
import '../auth/fake_http_client_adapter.dart';
import '../auth/fake_secure_storage.dart';

void main() {
  late FakeSecureStorage storage;
  late TokenStorage tokens;
  late ApiClient api;
  late StagingPushTestController controller;
  late List<RequestOptions> requests;
  String? owner;
  int status = 200;
  bool offline = false;
  setUp(() async {
    storage = FakeSecureStorage();
    tokens = TokenStorage(storage);
    owner = 'owner-id';
    status = 200;
    offline = false;
    requests = [];
    await tokens.save(
      accessToken: 'fixture-session',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
    await tokens.saveActiveUserId(owner!);
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.example/api/v1'));
    dio.httpClientAdapter = FakeHttpClientAdapter((request) {
      requests.add(request);
      return offline
          ? const FakeResponse.networkFailure()
          : FakeResponse(
              statusCode: status,
              body: {
                'data': {
                  'invocation_id': (request.data as Map)['invocation_id'],
                  'provider_result': 'ACCEPTED',
                  'delivery_confirmed': false,
                },
                'error': {'message': 'secret-provider-token'},
              },
            );
    });
    api =
        ApiClient(baseUrl: dio.options.baseUrl, tokenStorage: tokens, dio: dio);
    controller = StagingPushTestController(
      api: api,
      storage: storage,
      ownerId: () => owner,
    );
    await controller.load();
  });
  tearDown(() {
    controller.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test('only staging OWNER Android can see the action', () {
    for (final environment in AppEnvironment.values) {
      expect(
        stagingTestVisible(environment, true, true),
        environment == AppEnvironment.staging,
      );
    }
    expect(stagingTestVisible(AppEnvironment.staging, false, true), false);
    expect(stagingTestVisible(AppEnvironment.staging, true, false), false);
  });
  test(
      'requires confirmation, sends one UUID with existing auth and blocks duplicate taps',
      () async {
    await controller.send(confirmed: false);
    expect(requests, isEmpty);
    await Future.wait(
      [controller.send(confirmed: true), controller.send(confirmed: true)],
    );
    expect(requests, hasLength(1));
    expect(requests.single.headers['Authorization'], 'Bearer fixture-session');
    expect(requests.single.path, '/notifications/push/staging-test');
    final body = requests.single.data as Map;
    expect(body.keys.toSet(), {'invocation_id', 'confirmation'});
    expect(body['confirmation'], 'SEND_ONE_STAGING_TEST');
    expect(
      body['invocation_id'],
      matches(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ),
      ),
    );
    expect(controller.message, contains('delivery is not yet confirmed'));
  });
  test('uncertain network result stays consumed across controller recreation',
      () async {
    offline = true;
    await controller.send(confirmed: true);
    expect(controller.message, contains('may have been sent'));
    controller.dispose();
    controller = StagingPushTestController(
      api: api,
      storage: storage,
      ownerId: () => owner,
    );
    await controller.load();
    await controller.send(confirmed: true);
    expect(controller.consumed, true);
    expect(requests, hasLength(1));
  });
  test('401 never triggers automatic refresh and replay', () async {
    status = 401;
    int refreshes = 0;
    api.sessionRefresher = () async {
      refreshes++;
      return 'new-fixture';
    };
    await controller.send(confirmed: true);
    expect(requests, hasLength(1));
    expect(refreshes, 0);
    expect(controller.consumed, true);
    expect(controller.message, isNot(contains('secret-provider-token')));
  });
  test('403 remains disabled and sanitized', () async {
    status = 403;
    await controller.send(confirmed: true);
    await controller.send(confirmed: true);
    expect(requests, hasLength(1));
    expect(controller.consumed, true);
    expect(controller.message, isNot(contains('secret-provider-token')));
  });
  test('missing session or changed account never submits', () async {
    await tokens.clear();
    await controller.send(confirmed: true);
    expect(requests, isEmpty);
    owner = null;
    await controller.load();
    await controller.send(confirmed: true);
    expect(requests, isEmpty);
  });
  test('API rejects account mismatch before transmission', () async {
    await tokens.saveActiveUserId('another-user');
    await controller.send(confirmed: true);
    expect(requests, isEmpty);
    expect(controller.consumed, true);
  });
  test('diagnostic receipt has no signal route and ignores raw content', () {
    final receipt = PhoneAlert.parse({
      'event_id': '12345678-1234-4234-8234-123456789012',
      'type': 'STAGING_PUSH_TEST',
      'title': 'secret-provider-token',
    });
    expect(receipt!.isStagingTest, true);
    expect(receipt.signalPath, '/settings');
    expect(receipt.title, 'Staging test notification received.');
  });
  testWidgets(
      'confirmation cancellation sends nothing; confirmed button remains disabled',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const user = AuthUser(
      id: 'owner-id',
      email: 'fixture@example.test',
      displayName: 'Owner',
      role: AppRole.owner,
      permissions: PermissionSet.owner,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(AppEnvironment.staging),
          currentUserProvider.overrideWithValue(user),
          stagingPushTestProvider.overrideWithValue(controller),
        ],
        child: const MaterialApp(home: Scaffold(body: StagingPushTestAction())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Test Notification'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    await tester.tap(find.text('Send Test Notification'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send once'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Send Test Notification'),
          )
          .onPressed,
      isNull,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
