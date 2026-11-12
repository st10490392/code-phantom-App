import 'dart:convert';

/// A frame broadcast by the trading bridge's `/api/v1/stream` endpoint.
///
/// Parsing is strict on purpose: a frame this build cannot understand is
/// dropped rather than guessed at, so a bridge that changes shape shows up as
/// "no events" rather than as fabricated signal or position data.
sealed class LiveFeedEvent {
  const LiveFeedEvent(this.raw, {required this.type});

  /// The bridge's `type` field, verbatim (`hello`/`signal`/`trade_event`/
  /// `control`/`license`/`push`).
  final String type;

  /// The parsed frame, kept so the diagnostics panel can show what actually
  /// arrived. Never contains a licence key or any other credential.
  final Map<String, dynamic> raw;

  /// Identity used for duplicate suppression. The bridge has no event id, so
  /// this is a content key: two identical frames in a row are one event.
  String get dedupeKey =>
      '$type|${raw['kind']}|${raw['ticket']}|${raw['symbol']}|'
      '${raw['message']}|${raw['action']}|${raw['service_type']}|${raw['hardware_id']}';
}

/// `{"type":"hello","service":"SIGNALS"}` — the socket is authenticated and
/// subscribed; this is the moment the connection counts as live.
final class HelloEvent extends LiveFeedEvent {
  const HelloEvent(super.raw, {required this.service}) : super(type: 'hello');
  final String service;
}

/// `{"type":"signal", …}` — a strategy produced a candidate; `dispatched`
/// distinguishes a live entry from a suppressed one (`gate` says why).
final class SignalEvent extends LiveFeedEvent {
  const SignalEvent(super.raw, {
    required this.symbol,
    required this.strategy,
    required this.direction,
    required this.dispatched,
    required this.kind,
    this.ticket,
  }) : super(type: 'signal');

  final String symbol;
  final String strategy;
  final String direction;
  final bool dispatched;

  /// `entry` when the order was sent, `suppressed` when a gate refused it.
  final String kind;
  final int? ticket;
}

/// `{"type":"trade_event", "kind": entry|break_even|partial_tp|exit|drawdown}`
/// — the lifecycle of a live MT5 position.
final class TradeEvent extends LiveFeedEvent {
  const TradeEvent(super.raw, {
    required this.kind,
    this.ticket,
    this.symbol,
    this.rMultiple,
    this.message,
    this.drawdownR,
  }) : super(type: 'trade_event');

  final String kind;
  final int? ticket;
  final String? symbol;
  final double? rMultiple;
  final String? message;
  final double? drawdownR;
}

/// `{"type":"control","action":…,"paused":bool,"sub":…}` — the daemon's
/// pause/resume state changed (Telegram, API, or another client).
final class ControlEvent extends LiveFeedEvent {
  const ControlEvent(super.raw, {required this.action, required this.paused})
      : super(type: 'control');

  final String action;
  final bool paused;
}

/// `{"type":"license","service_type":…,"hardware_id":…}` — an activation was
/// recorded. Only the service type is ever shown; no key is in the frame.
final class LicenseEvent extends LiveFeedEvent {
  const LicenseEvent(super.raw, {required this.serviceType}) : super(type: 'license');

  final String serviceType;
}

/// `{"type":"push","action":register|unregister,"hardware_id":…}` — a device
/// registration changed for this licence's hardware id.
final class PushEvent extends LiveFeedEvent {
  const PushEvent(super.raw, {required this.action, required this.hardwareId})
      : super(type: 'push');

  final String action;
  final String hardwareId;
}


const _serviceTypes = {'EA', 'SIGNALS'};
const _tradeKinds = {'entry', 'break_even', 'partial_tp', 'exit', 'drawdown'};
const _signalKinds = {'entry', 'suppressed'};
const _directions = {'BUY', 'SELL'};
const _pushActions = {'register', 'unregister'};
const _controlActions = {'pause', 'resume', 'toggle'};

int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
double? _asDouble(Object? v) => v is num ? v.toDouble() : null;
bool _isServiceType(Object? v) => v is String && _serviceTypes.contains(v);

/// Parses one decoded frame, or returns `null` for anything malformed or of an
/// unknown `type`. A frame with a missing or mistyped required field is dropped
/// too — a partial frame must never render as a signal or lifecycle event.
LiveFeedEvent? parseLiveFeedEvent(Map<String, dynamic> frame) {
  final type = frame['type'];
  if (type is! String) return null;

  switch (type) {
    case 'hello':
      if (!_isServiceType(frame['service'])) return null;
      return HelloEvent(frame, service: frame['service'] as String);

    case 'signal':
      final symbol = frame['symbol'];
      final strategy = frame['strategy'];
      final direction = frame['direction'];
      final kind = frame['kind'];
      final dispatched = frame['dispatched'];
      if (symbol is! String || symbol.isEmpty) return null;
      if (strategy is! String || strategy.isEmpty) return null;
      if (direction is! String || !_directions.contains(direction)) return null;
      if (dispatched is! bool) return null;
      if (kind is! String || !_signalKinds.contains(kind)) return null;
      return SignalEvent(
        frame,
        symbol: symbol,
        strategy: strategy,
        direction: direction,
        dispatched: dispatched,
        kind: kind,
        ticket: _asInt(frame['ticket']),
      );

    case 'trade_event':
      // `manage_active_positions()` telemetry frames carry only a message, so
      // `kind` is absent for those — still a real lifecycle line, not a guess.
      final kind = frame['kind'];
      final message = frame['message'];
      if (kind != null && kind is! String) return null;
      if (message != null && message is! String) return null;
      if (kind == null && message == null) return null;
      if (kind is String && !_tradeKinds.contains(kind)) return null;
      return TradeEvent(
        frame,
        kind: kind ?? 'telemetry',
        ticket: _asInt(frame['ticket']),
        symbol: frame['symbol'] is String ? frame['symbol'] as String : null,
        rMultiple: _asDouble(frame['r_multiple']),
        message: message is String ? message : null,
        drawdownR: _asDouble(frame['drawdown_r']),
      );

    case 'control':
      final action = frame['action'];
      final paused = frame['paused'];
      if (action is! String || !_controlActions.contains(action)) return null;
      if (paused is! bool) return null;
      return ControlEvent(frame, action: action, paused: paused);

    case 'license':
      if (!_isServiceType(frame['service_type'])) return null;
      return LicenseEvent(frame, serviceType: frame['service_type'] as String);

    case 'push':
      final action = frame['action'];
      final hardwareId = frame['hardware_id'];
      if (action is! String || !_pushActions.contains(action)) return null;
      if (hardwareId is! String || hardwareId.isEmpty) return null;
      return PushEvent(frame, action: action, hardwareId: hardwareId);

    default:
      return null;
  }
}

/// Decodes and parses one WebSocket frame. Non-JSON and non-object frames are
/// dropped rather than surfaced as an error, so a keepalive or a future frame
/// type cannot tear the feed down.
LiveFeedEvent? parseLiveFeedFrame(Object? payload) {
  if (payload is! String) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(payload);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  return parseLiveFeedEvent(Map<String, dynamic>.from(decoded));
}
