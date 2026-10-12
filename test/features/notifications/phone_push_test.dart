import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/network/api_client.dart';
import 'package:code_phantom_app/core/storage/token_storage.dart';
import 'package:code_phantom_app/features/notifications/push/phone_alert.dart';
import 'package:code_phantom_app/features/notifications/push/phone_push_controller.dart';
import 'package:code_phantom_app/features/notifications/push/push_transport.dart';
import '../auth/fake_http_client_adapter.dart';
import '../auth/fake_secure_storage.dart';

class FakePushTransport implements PushTransport {
  bool allowed = true;
  int prompts = 0;
  int deleted = 0;
  String? currentToken = 'phone-token-1234567890';
  Completer<String?>? delayedToken;
  PhoneAlert? initial;
  final refresh = StreamController<String>.broadcast();
  final messages = StreamController<PhoneAlert>.broadcast();
  final taps = StreamController<PhoneAlert>.broadcast();
  @override
  Future<bool> permission({required bool prompt}) async {
    if (prompt) prompts++;
    return allowed;
  }

  @override
  Future<String?> token() => delayedToken?.future ?? Future.value(currentToken);
  @override
  Future<void> deleteToken() async {
    deleted++;
  }

  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Stream<PhoneAlert> get foreground => messages.stream;
  @override
  Stream<PhoneAlert> get opened => taps.stream;
  @override
  Future<PhoneAlert?> initialAlert() async => initial;
  Future<void> close() async {
    await refresh.close();
    await messages.close();
    await taps.close();
  }
}

const data = {
  'event_id': '12345678-1234-1234-1234-123456789012',
  'signal_id': '87654321-4321-4321-4321-210987654321',
  'type': 'TP',
};

void main() {
  test('push routing only uses validated signal UUID, never payload routes',
      () {
    final alert = PhoneAlert.parse(
      {...data, 'url': 'https://evil.example', 'strategy': 'private'},
    )!;
    expect(alert.signalPath, '/signals/${data['signal_id']}');
    expect(PhoneAlert.parse({...data, 'signal_id': '../ea'}), isNull);
    expect(PhoneAlert.parse({...data, 'type': 'private'}), isNull);
  });
  late FakeSecureStorage storage;
  late FakePushTransport transport;
  late PhonePushController controller;
  late List<RequestOptions> requests;
  var offline = false;
  var responseStatus = 200;
  Map<String, dynamic> responseBody = {};
  late TokenStorage tokens;
  final deviceIds = <String, String>{};
  setUp(() async {
    storage = FakeSecureStorage();
    transport = FakePushTransport();
    requests = [];
    offline = false;
    responseStatus = 200;
    responseBody = {'data': {'id': '33333333-3333-4333-8333-333333333333'}};
    deviceIds.clear();
    tokens = TokenStorage(storage);
    await tokens.save(
      accessToken: 'user-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.example/api/v1'));
    dio.httpClientAdapter = FakeHttpClientAdapter((options) {
      requests.add(options);
      return offline
          ? const FakeResponse.networkFailure()
          : FakeResponse(statusCode: responseStatus, body: responseBody);
    });
    controller = PhonePushController(
      api: ApiClient(
        baseUrl: dio.options.baseUrl,
        tokenStorage: tokens,
        dio: dio,
      ),
      storage: storage,
      platform: 'ANDROID',
      boundDeviceId: (userId) async => deviceIds[userId],
      createTransport: () async => transport,
    );
  });
  tearDown(() async {
    controller.dispose();
    await transport.close();
  });

  test('push uses the current account binding and ignores the legacy global id',
      () async {
    await storage.write('account_device_id', 'another-account-legacy-id');
    deviceIds['alice'] = '11111111-1111-4111-8111-111111111111';
    deviceIds['bob'] = '22222222-2222-4222-8222-222222222222';
    await controller.setUser('alice');
    await controller.enable();
    expect((requests.last.data as Map)['device_id'], deviceIds['alice']);
    await controller.beforeLogout();
    await controller.setUser('bob');
    await controller.enable();
    expect((requests.last.data as Map)['device_id'], deviceIds['bob']);
    await controller.beforeLogout();
    await controller.setUser('unbound');
    await controller.enable();
    expect((requests.last.data as Map).containsKey('device_id'), isFalse);
  });

  test('restoring a session never prompts or registers without explicit opt-in',
      () async {
    await controller.setUser('user');
    expect(transport.prompts, 0);
    expect(requests, isEmpty);
    await controller.enable();
    expect(transport.prompts, 1);
    final request = requests.single;
    expect(request.path, '/notifications/push/register');
    expect(request.headers['Authorization'], 'Bearer user-token');
    expect(
      (request.data as Map).keys.toSet(),
      {'installation_id', 'token', 'platform'},
    );
    expect(
      await storage.read('push_installation_id'),
      matches(RegExp(r'^[a-f0-9-]{36}$')),
    );
  });

  test('unlicensed OWNER submits no claimed role or invented licence binding', () async {
    await controller.setUser('owner');
    await controller.enable();
    expect(controller.registered, isTrue);
    expect((requests.single.data as Map).keys.toSet(), {'installation_id', 'token', 'platform'});
    expect(requests.single.headers['Authorization'], 'Bearer user-token');
  });

  test('licensed CLIENT retains the current account device binding', () async {
    deviceIds['client'] = '11111111-1111-4111-8111-111111111111';
    await controller.setUser('client');
    await controller.enable();
    expect(controller.registered, isTrue);
    expect((requests.single.data as Map)['device_id'], deviceIds['client']);
  });

  test('missing authentication never sends a registration request', () async {
    await tokens.clear();
    await controller.setUser('owner');
    await controller.enable();
    expect(requests, isEmpty);
    expect(controller.registered, isFalse);
    expect(controller.error, contains('Sign in again'));
  });

  test('invalid stored device identity fails before HTTP', () async {
    deviceIds['client'] = 'invalid-device';
    await controller.setUser('client');
    await controller.enable();
    expect(requests, isEmpty);
    expect(controller.registered, isFalse);
    expect(controller.error, isNotNull);
  });

  test('backend device denial remains denied and has a sanitized message', () async {
    responseStatus = 403;
    responseBody = {'error': {'code': 'DEVICE_REQUIRED', 'message': 'fixture-sensitive-details'}};
    await controller.setUser('owner');
    await controller.enable();
    expect(controller.registered, isFalse);
    expect(controller.error, contains('not authorized'));
    expect(controller.error, isNot(contains('fixture-sensitive-details')));
    responseStatus = 200;
    responseBody = {'data': {'id': '33333333-3333-4333-8333-333333333333'}};
    await controller.resume();
    expect(controller.registered, isTrue);
  });

  test('malformed successful response never claims registration', () async {
    responseBody = {'data': {}};
    await controller.setUser('owner');
    await controller.enable();
    expect(controller.registered, isFalse);
    expect(controller.error, isNotNull);
  });

  test('denied permission creates no backend token registration', () async {
    transport.allowed = false;
    await controller.setUser('user');
    await controller.enable();
    expect(controller.enabled, false);
    expect(requests, isEmpty);
    expect(controller.error, contains('phone settings'));
  });

  test(
      'anonymous cold start retries pending SDK token deletion without registering',
      () async {
    await storage.write('push_pending_unregister', 'true');
    await storage.write('push_enabled', 'false');
    await controller.setUser(null);
    expect(transport.deleted, 1);
    expect(requests, isEmpty);
    expect(controller.enabled, false);
  });

  test(
      'persisted foreground receipt suppresses restart duplicates but not taps',
      () async {
    await storage.write('push_seen_user_foreground', '["${data['event_id']}"]');
    final foreground = <PhoneAlert>[], opened = <PhoneAlert>[];
    final a = controller.foreground.listen(foreground.add),
        b = controller.opened.listen(opened.add);
    await controller.setUser('user');
    await controller.enable();
    transport.messages.add(PhoneAlert.parse(data)!);
    transport.taps.add(PhoneAlert.parse(data)!);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await controller.resume();
    expect(foreground, isEmpty);
    expect(opened.length, 1);
    await a.cancel();
    await b.cancel();
  });

  test(
      'foreground events deduplicate and taps retain a separate deduplication set',
      () async {
    transport.initial = PhoneAlert.parse(data);
    final opened = <PhoneAlert>[], foreground = <PhoneAlert>[];
    final a = controller.opened.listen(opened.add),
        b = controller.foreground.listen(foreground.add);
    await controller.setUser('user');
    await controller.enable();
    final alert = PhoneAlert.parse(data)!;
    transport.messages.add(alert);
    transport.messages.add(alert);
    transport.taps.add(alert);
    transport.taps.add(alert);
    await Future<void>.delayed(Duration.zero);
    expect(foreground.length, 1);
    expect(opened.length, 1);
    expect(foreground.single.title, 'CPT Market Update · TP reached');
    await a.cancel();
    await b.cancel();
  });

  test(
      'refresh rotates the token with the same installation and optional verified device reference',
      () async {
    deviceIds['user'] = '11111111-1111-4111-8111-111111111111';
    await controller.setUser('user');
    await controller.enable();
    final installation = (requests.single.data as Map)['installation_id'];
    transport.refresh.add('new-phone-token-123456');
    await Future<void>.delayed(Duration.zero);
    await controller.resume();
    final rotated = requests
        .where((r) => (r.data as Map)['token'] == 'new-phone-token-123456')
        .single;
    expect((rotated.data as Map)['installation_id'], installation);
    expect((rotated.data as Map)['device_id'], deviceIds['user']);
  });

  test(
      'logout unregisters before clearing credentials and ignores later refresh callbacks',
      () async {
    await controller.setUser('user');
    await controller.enable();
    await controller.beforeLogout();
    expect(controller.enabled, false);
    expect(await storage.read('push_enabled'), 'false');
    expect(requests.last.path, '/notifications/push/unregister');
    expect(transport.deleted, 1);
    final count = requests.length;
    transport.refresh.add('late-phone-token-12345');
    await Future<void>.delayed(Duration.zero);
    await controller.resume();
    expect(requests.length, count);
  });

  test('logout cancels a token lookup still in progress', () async {
    await controller.setUser('user');
    transport.delayedToken = Completer<String?>();
    final enabling = controller.enable();
    await Future<void>.delayed(Duration.zero);
    final logout = controller.beforeLogout();
    transport.delayedToken!.complete('late-phone-token-12345');
    await enabling;
    await logout;
    expect(requests.where((r) => r.path.endsWith('/register')), isEmpty);
  });

  test('transient registration failure is visible and retries on resume',
      () async {
    await controller.setUser('user');
    offline = true;
    await controller.enable();
    expect(controller.error, contains('Try again'));
    offline = false;
    await controller.resume();
    expect(controller.error, isNull);
    expect(requests.last.path, '/notifications/push/register');
  });

  test(
      'offline opt-out deletes the local token and retries server unregister on resume',
      () async {
    await controller.setUser('user');
    await controller.enable();
    offline = true;
    await controller.disable();
    expect(controller.enabled, false);
    expect(transport.deleted, 1);
    expect(await storage.read('push_pending_unregister'), 'true');
    offline = false;
    await controller.resume();
    expect(requests.last.path, '/notifications/push/unregister');
    expect(await storage.read('push_pending_unregister'), isNull);
  });

  test('missing APNs/FCM token does not post null and retries later', () async {
    transport.currentToken = null;
    await controller.setUser('user');
    await controller.enable();
    expect(requests, isEmpty);
    expect(controller.error, contains('connecting'));
    transport.currentToken = 'ready-phone-token-123456';
    await controller.resume();
    expect(requests.length, 1);
  });

  test('unsupported/mock builds never initialize Firebase', () async {
    controller.dispose();
    controller = PhonePushController(
      api: ApiClient(
        baseUrl: 'https://backend.example',
        tokenStorage: TokenStorage(storage),
      ),
      storage: storage,
      platform: 'WEB',
      createTransport: null,
    );
    await controller.setUser('user');
    await controller.enable();
    expect(controller.available, false);
    expect(transport.prompts, 0);
    expect(requests, isEmpty);
  });

  test('payload parsing never accepts arbitrary routes or displays metadata',
      () {
    final alert = PhoneAlert.parse({
      ...data,
      'strategy': 'GILGAMESH',
      'hash': 'private',
      'title': 'private',
      'route': 'https://evil.example',
    });
    expect(alert!.title, 'CPT Market Update · TP reached');
    expect(PhoneAlert.parse({...data, 'type': 'GILGAMESH'}), isNull);
    expect(PhoneAlert.parse({...data, 'event_id': '../admin'}), isNull);
  });
}
