import 'dart:async';

import 'package:code_phantom_app/core/config/api_config.dart';
import 'package:code_phantom_app/core/device/device_identity.dart';
import 'package:code_phantom_app/core/storage/bridge_credentials.dart';
import 'package:code_phantom_app/features/live_feed/data/live_feed_service.dart';
import 'package:code_phantom_app/features/live_feed/data/live_feed_transport.dart';
import 'package:code_phantom_app/features/live_feed/domain/live_feed_event.dart';
import 'package:flutter_test/flutter_test.dart';
import '../auth/fake_secure_storage.dart';

/// Scripted socket: the test decides what the bridge "sends", so reconnect and
/// duplicate handling are exercised without a network. Every connection gets
/// its own message stream, exactly as a real socket does.
class _FakeTransport implements LiveFeedTransport {
  _FakeTransport({this.failConnect = false});

  final bool failConnect;
  final List<Uri> connections = [];
  final List<String> sent = [];
  int closeCount = 0;
  final connected = Completer<void>();
  StreamController<dynamic>? _messages;

  @override
  Stream<dynamic> get messages => _messages!.stream;

  void emit(Object? frame) => _messages?.add(frame);

  /// Simulates the socket dropping mid-session, after the service has
  /// subscribed — which is the case the reconnect logic exists for.
  Future<void> dropCurrent() async {
    final messages = _messages;
    _messages = null;
    if (messages != null && !messages.isClosed) await messages.close();
  }

  @override
  Future<void> connect(Uri uri) async {
    connections.add(uri);
    // A socket is a single-subscription stream, like a real one.
    _messages = StreamController<dynamic>();
    if (failConnect) throw const SocketExceptionStub();
    if (!connected.isCompleted) connected.complete();
  }

  @override
  Future<void> send(String frame) async => sent.add(frame);

  @override
  Future<void> close() async {
    closeCount++;
    final messages = _messages;
    _messages = null;
    if (messages != null && !messages.isClosed) await messages.close();
  }
}

class _Fixture {
  _Fixture(this.service, this.transport);
  final BridgeLiveFeedService service;
  final _FakeTransport transport;
}

Future<_Fixture> _fixture({
  bool failConnect = false,
  String? signalsKey = 'PH-SIGNALS-DEADBEEF',
  int maxConsecutiveFailures = 3,
}) async {
  final storage = FakeSecureStorage();
  final credentials = BridgeCredentialStorage(storage);
  if (signalsKey != null) await credentials.saveSignalsKey(signalsKey);
  final transport = _FakeTransport(failConnect: failConnect);
  final service = BridgeLiveFeedService(
    credentials: credentials,
    identity: DeviceIdentity(storage),
    transport: transport,
    streamUri: Uri.parse('ws://bridge.test/api/v1/stream'),
    heartbeatInterval: const Duration(milliseconds: 5),
    backoffBase: const Duration(milliseconds: 1),
    backoffCap: const Duration(milliseconds: 2),
    maxConsecutiveFailures: maxConsecutiveFailures,
  );
  addTearDown(service.dispose);
  return _Fixture(service, transport);
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  test('subscribes with the SIGNALS key and this hardware id in the query', () async {
    final f = await _fixture();
    await f.service.start();
    await f.transport.connected.future;
    final uri = f.transport.connections.single;
    expect(uri.queryParameters['key'], 'PH-SIGNALS-DEADBEEF');
    final hardwareId = uri.queryParameters['hardware_id'];
    expect(hardwareId, isNotNull);
    expect(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(hardwareId!),
      isTrue,
    );
  });

  test('only hello marks the feed live; nothing is claimed before it', () async {
    final f = await _fixture();
    final statuses = <LiveFeedStatus>[];
    final sub = f.service.statuses.listen(statuses.add);
    await f.service.start();
    await f.transport.connected.future;
    expect(f.service.status, LiveFeedStatus.connecting);
    f.transport.emit('{"type":"hello","service":"SIGNALS"}');
    await _settle();
    expect(f.service.status, LiveFeedStatus.live);
    expect(statuses, contains(LiveFeedStatus.connecting));
    await sub.cancel();
  });

  test('identical frames collapse to one event', () async {
    final f = await _fixture();
    final events = <LiveFeedEvent>[];
    final sub = f.service.events.listen(events.add);
    await f.service.start();
    await f.transport.connected.future;
    const frame = '{"type":"trade_event","kind":"exit","ticket":7,"symbol":"US30","message":"CLOSED US30"}';
    f.transport.emit(frame);
    f.transport.emit(frame);
    f.transport.emit(frame);
    await _settle();
    expect(events, hasLength(1));
    await sub.cancel();
  });

  test('an unknown frame is dropped without ending the subscription', () async {
    final f = await _fixture();
    final events = <LiveFeedEvent>[];
    final sub = f.service.events.listen(events.add);
    await f.service.start();
    await f.transport.connected.future;
    f.transport.emit('{"type":"positions","positions":[]}');
    f.transport.emit('{"type":"control","action":"pause","paused":true}');
    await _settle();
    expect(events, hasLength(1));
    // Subscribed, but never claimed "live": only `hello` proves the
    // subscription was accepted by the bridge.
    expect(f.service.status, LiveFeedStatus.connecting);
    await sub.cancel();
  });

  test('a keepalive is sent so the bridge keeps the socket warm', () async {
    final f = await _fixture();
    await f.service.start();
    await f.transport.connected.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(f.transport.sent, contains('ping'));
  });


  test('a refused licence stops retrying and never names the key', () async {
    final f = await _fixture(failConnect: true);
    final problems = <String>[];
    final statuses = <LiveFeedStatus>[];
    final problemSub = f.service.problems.listen(problems.add);
    final statusSub = f.service.statuses.listen(statuses.add);
    await f.service.start();
    await _settle();
    await _settle();
    expect(f.service.status, LiveFeedStatus.unavailable);
    // Hard ceiling: reconnection is bounded, never an infinite loop.
    expect(f.transport.connections.length, lessThanOrEqualTo(3));
    expect(problems, hasLength(1));
    expect(problems.single, isNot(contains('PH-SIGNALS')));
    expect(problems.single, isNot(contains('DEADBEEF')));
    expect(statuses, contains(LiveFeedStatus.reconnecting));
    await problemSub.cancel();
    await statusSub.cancel();
  });

  test('a dropped socket reconnects, then gives up at the ceiling', () async {
    final f = await _fixture(maxConsecutiveFailures: 2);
    final statuses = <LiveFeedStatus>[];
    final subscription = f.service.statuses.listen(statuses.add);
    addTearDown(subscription.cancel);

    await f.service.start();
    await f.transport.connected.future;

    await f.transport.dropCurrent();
    await _settle();
    // Backoff state first, then the retry itself — both are real states the
    // dashboard must be able to show.
    expect(statuses, contains(LiveFeedStatus.reconnecting));
    expect(f.transport.connections.length, 2);

    await f.transport.dropCurrent();
    await _settle();
    expect(f.service.status, LiveFeedStatus.unavailable);
    // The ceiling is what stops the loop: no further attempt is scheduled.
    await _settle();
    expect(f.transport.connections.length, 2);
  });

  test('stop() closes the socket and reports unauthenticated', () async {
    final f = await _fixture();
    await f.service.start();
    await f.transport.connected.future;
    await f.service.stop();
    expect(f.transport.closeCount, 1);
    expect(f.service.status, LiveFeedStatus.unauthenticated);
  });

  test('no stored key means no connection attempt at all', () async {
    final f = await _fixture(signalsKey: null);
    await f.service.start();
    expect(f.transport.connections, isEmpty);
    expect(f.service.status, LiveFeedStatus.unauthenticated);
  });

  test('restart() re-subscribes with the stored key', () async {
    final f = await _fixture();
    await f.service.start();
    await f.transport.connected.future;
    await f.service.restart();
    expect(f.transport.connections, hasLength(2));
    expect(f.transport.connections.last.queryParameters['key'], 'PH-SIGNALS-DEADBEEF');
  });

  test('dispose closes the socket and stops the keepalive', () async {
    final f = await _fixture();
    await f.service.start();
    await f.transport.connected.future;
    await f.service.dispose();
    expect(f.transport.closeCount, greaterThan(0));
    final sentAfterDispose = f.transport.sent.length;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(f.transport.sent.length, sentAfterDispose);
  });

  test('a build with no bridge configured is unconfigured, not offline', () async {
    final storage = FakeSecureStorage();
    final service = BridgeLiveFeedService(
      credentials: BridgeCredentialStorage(storage),
      identity: DeviceIdentity(storage),
      transport: _FakeTransport(),
      streamUri: ApiConfig.bridgeStreamUri, // unset in tests: BRIDGE_BASE_URL is not defined
    );
    addTearDown(service.dispose);
    await service.start();
    expect(service.status, LiveFeedStatus.unconfigured);
    expect(ApiConfig.bridgeStreamUri, isNull);
    expect(ApiConfig.bridgeConfigured, isFalse);
  });

  test('mock mode invents no trading events', () async {
    final service = MockLiveFeedService();
    addTearDown(service.dispose);
    final statuses = <LiveFeedStatus>[];
    final events = <LiveFeedEvent>[];
    final statusSub = service.statuses.listen(statuses.add);
    final eventSub = service.events.listen(events.add);
    await service.start();
    expect(statuses, [LiveFeedStatus.unconfigured]);
    expect(events, isEmpty);
    await statusSub.cancel();
    await eventSub.cancel();
  });
}
