import 'dart:async';

import '../../../core/config/api_config.dart';
import '../../../core/device/device_identity.dart';
import '../../../core/storage/bridge_credentials.dart';
import '../domain/live_feed_event.dart';
import 'live_feed_transport.dart';

/// State of the live feed, surfaced to the UI so a disconnected bridge is
/// shown as disconnected rather than as "no signals".
enum LiveFeedStatus {
  /// No `SIGNALS` key for this device yet — nothing to authenticate with.
  unauthenticated,

  /// No bridge configured for this build (`BRIDGE_BASE_URL` unset).
  unconfigured,

  connecting,

  /// `hello` received: authenticated and subscribed.
  live,

  /// Socket dropped; a reconnect is scheduled.
  reconnecting,

  /// Reconnection gave up, or the bridge refused the licence key.
  unavailable,
}

/// Frames broadcast by the live trading bridge, as parsed domain events.
abstract interface class LiveFeedService {
  Stream<LiveFeedEvent> get events;
  Stream<LiveFeedStatus> get statuses;
  Stream<String> get problems;

  Future<void> start();

  /// Re-subscribes after the stored key changes (a fresh activation).
  Future<void> restart();

  Future<void> stop();
  Future<void> dispose();
}

/// Real feed against `GET /api/v1/stream?key=<SIGNALS>&hardware_id=<id>`.
///
/// The rules this implementation exists to enforce: exponential backoff with a
/// hard attempt ceiling (never an infinite reconnect loop), a keepalive frame so
/// the bridge keeps the socket warm, content-keyed duplicate suppression, and
/// disposal that cancels every subscription and closes the socket. The licence
/// key goes in the query string and is never logged or echoed in a message — the
/// only text this class emits is the reason a connection failed.
class BridgeLiveFeedService implements LiveFeedService {
  BridgeLiveFeedService({
    required this.credentials,
    required this.identity,
    required LiveFeedTransport transport,
    Uri? streamUri,
    this.heartbeatInterval = const Duration(seconds: 20),
    this.backoffBase = const Duration(seconds: 1),
    this.backoffCap = const Duration(seconds: 30),
    int maxConsecutiveFailures = 6,
  }) : _transport = transport,
       _streamUri = streamUri ?? ApiConfig.bridgeStreamUri,
       _maxConsecutiveFailures = maxConsecutiveFailures;

  final BridgeCredentialStorage credentials;
  final DeviceIdentity identity;
  final LiveFeedTransport _transport;
  final Uri? _streamUri;
  final Duration heartbeatInterval;
  final Duration backoffBase;
  final Duration backoffCap;
  final int _maxConsecutiveFailures;

  final _events = StreamController<LiveFeedEvent>.broadcast();
  final _statuses = StreamController<LiveFeedStatus>.broadcast();
  final _problems = StreamController<String>.broadcast();

  StreamSubscription<dynamic>? _messages;
  Timer? _heartbeat;
  Timer? _retry;
  bool _disposed = false;
  bool _wantConnection = false;
  int _consecutiveFailures = 0;
  LiveFeedStatus _status = LiveFeedStatus.unauthenticated;
  final _seen = <String>{};
  static const _seenCap = 200;

  @override
  Stream<LiveFeedEvent> get events => _events.stream;

  @override
  Stream<LiveFeedStatus> get statuses => _statuses.stream;

  @override
  Stream<String> get problems => _problems.stream;

  LiveFeedStatus get status => _status;

  @override
  Future<void> start() async {
    if (_disposed) return;
    _wantConnection = true;
    await _attempt();
  }

  @override
  Future<void> restart() async {
    await _teardownSocket();
    _consecutiveFailures = 0;
    await start();
  }

  @override
  Future<void> stop() async {
    _wantConnection = false;
    _retry?.cancel();
    _retry = null;
    await _teardownSocket();
    _emit(LiveFeedStatus.unauthenticated);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _wantConnection = false;
    _retry?.cancel();
    _heartbeat?.cancel();
    await _teardownSocket();
    await _messages?.cancel();
    _messages = null;
    await _events.close();
    await _statuses.close();
    await _problems.close();
  }


  Future<void> _attempt() async {
    if (_disposed || !_wantConnection) return;
    final uri = _streamUri;
    if (uri == null) {
      _emit(LiveFeedStatus.unconfigured);
      return;
    }
    final key = await credentials.readSignalsKey();
    if (key == null) {
      _emit(LiveFeedStatus.unauthenticated);
      return;
    }

    _emit(LiveFeedStatus.connecting);
    final hardwareId = await identity.hardwareId();
    final request = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'key': key,
      'hardware_id': hardwareId,
    },);

    try {
      await _transport.connect(request);
    } catch (_) {
      // Deliberately drops the exception text: the bridge's close reason is the
      // licence error, and a rejected key must never reach a UI string or a log.
      _fail('The trading bridge refused this device\'s SIGNALS key. Re-activate the licence.');
      return;
    }

    // The counter is only reset by an authenticated subscription (`hello`),
    // not by a bare handshake: a bridge that accepts the socket and then drops
    // it would otherwise be retried forever.
    _messages = _transport.messages.listen(
      _onFrame,
      onError: (_) => _fail('The live feed connection dropped.'),
      onDone: () => _fail('The live feed connection dropped.'),
      cancelOnError: true,
    );
    _heartbeat = Timer.periodic(heartbeatInterval, (_) async {
      try {
        await _transport.send('ping');
      } catch (_) {
        // A failed keepalive means the socket is gone; `onDone` handles it.
      }
    });
    // Not `live` yet: only `hello` proves the socket is authenticated and
    // subscribed, which is exactly what the dashboard claims.
    _emit(LiveFeedStatus.connecting);
  }

  void _onFrame(dynamic payload) {
    final event = parseLiveFeedFrame(payload);
    if (event == null) return;
    if (event is HelloEvent) {
      // An authenticated subscription proves the bridge is serving us, so the
      // backoff counter starts over for the next disconnect.
      _consecutiveFailures = 0;
      _emit(LiveFeedStatus.live);
      return;
    }
    if (!_seen.add(event.dedupeKey)) return;
    if (_seen.length > _seenCap) _seen.remove(_seen.first);
    _events.add(event);
  }

  /// One backoff step per failure, capped, and a hard ceiling after which this
  /// service stops retrying — the "no infinite reconnection loop" rule.
  void _fail(String problem) {
    _heartbeat?.cancel();
    _heartbeat = null;
    final messages = _messages;
    _messages = null;
    unawaited(messages?.cancel());
    unawaited(_transport.close());
    _consecutiveFailures++;
    if (_disposed || !_wantConnection || _consecutiveFailures >= _maxConsecutiveFailures) {
      _emit(LiveFeedStatus.unavailable);
      _problems.add(problem);
      return;
    }
    _emit(LiveFeedStatus.reconnecting);
    _retry?.cancel();
    final delay = backoffBase * (1 << (_consecutiveFailures - 1));
    _retry = Timer(delay > backoffCap ? backoffCap : delay, _attempt);
  }

  Future<void> _teardownSocket() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    final messages = _messages;
    _messages = null;
    await messages?.cancel();
    await _transport.close();
  }

  void _emit(LiveFeedStatus status) {
    _status = status;
    _statuses.add(status);
  }
}

/// Mock-mode feed: no socket and no invented trading events. It reports the
/// same states the real feed does, so the dashboard's disconnected state is
/// exercised without a live bridge.
class MockLiveFeedService implements LiveFeedService {
  final _events = StreamController<LiveFeedEvent>.broadcast();
  late final StreamController<LiveFeedStatus> _statuses = StreamController<LiveFeedStatus>.broadcast(
    onListen: () => _statuses.add(LiveFeedStatus.unconfigured),
  );
  final _problems = StreamController<String>.broadcast();

  @override
  Stream<LiveFeedEvent> get events => _events.stream;

  @override
  Stream<LiveFeedStatus> get statuses => _statuses.stream;

  @override
  Stream<String> get problems => _problems.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> restart() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _events.close();
    await _statuses.close();
    await _problems.close();
  }
}
