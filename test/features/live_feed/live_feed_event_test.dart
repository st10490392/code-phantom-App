import 'package:code_phantom_app/features/live_feed/data/live_feed_service.dart';
import 'package:code_phantom_app/features/live_feed/domain/live_feed_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bridge's real frame shapes, copied from `c:\CodePhantom`'s
/// `signal_pipeline.py` / `api_server.py` — not invented shapes.
Map<String, dynamic> hello() => {'type': 'hello', 'service': 'SIGNALS'};

Map<String, dynamic> entrySignal() => {
      'type': 'signal',
      'symbol': 'US30',
      'strategy': 'ORB',
      'direction': 'BUY',
      'dispatched': true,
      'gate': 'ok',
      'kind': 'entry',
      'ticket': 41,
    };

Map<String, dynamic> exitTradeEvent() => {
      'type': 'trade_event',
      'kind': 'exit',
      'ticket': 41,
      'symbol': 'US30',
      'strategy': 'ORB',
      'r_multiple': 1.75,
      'message': 'CLOSED US30 [ORB] TP2 at 1.75R',
    };

void main() {
  group('parseLiveFeedEvent', () {
    test('hello names the service this device subscribed as', () {
      final event = parseLiveFeedEvent(hello());
      expect(event, isA<HelloEvent>());
      expect((event as HelloEvent).service, 'SIGNALS');
    });

    test('a dispatched signal keeps direction, kind and ticket', () {
      final event = parseLiveFeedEvent(entrySignal()) as SignalEvent;
      expect(event.symbol, 'US30');
      expect(event.direction, 'BUY');
      expect(event.dispatched, isTrue);
      expect(event.kind, 'entry');
      expect(event.ticket, 41);
    });

    test('a suppressed signal is a real event, not a missing one', () {
      final event = parseLiveFeedEvent({
        'type': 'signal',
        'symbol': 'EURUSD',
        'strategy': 'Z_SCORE',
        'direction': 'SELL',
        'dispatched': false,
        'gate': 'cooldown',
        'kind': 'suppressed',
      }) as SignalEvent;
      expect(event.dispatched, isFalse);
      expect(event.kind, 'suppressed');
      expect(event.ticket, isNull);
    });

    test('a lifecycle frame carries its R-multiple', () {
      final event = parseLiveFeedEvent(exitTradeEvent()) as TradeEvent;
      expect(event.kind, 'exit');
      expect(event.ticket, 41);
      expect(event.rMultiple, 1.75);
      expect(event.message, contains('CLOSED US30'));
    });

    test('a message-only telemetry frame is still a lifecycle event', () {
      final event = parseLiveFeedEvent({
        'type': 'trade_event',
        'message': 'BREAK-EVEN US30 #41',
      }) as TradeEvent;
      expect(event.kind, 'telemetry');
      expect(event.message, 'BREAK-EVEN US30 #41');
    });

    test('control frames report the daemon state verbatim', () {
      final event = parseLiveFeedEvent({'type': 'control', 'action': 'pause', 'paused': true, 'sub': 'owner'}) as ControlEvent;
      expect(event.action, 'pause');
      expect(event.paused, isTrue);
    });

    test('licence and push frames never carry a key', () {
      expect(
        parseLiveFeedEvent({'type': 'license', 'service_type': 'SIGNALS', 'hardware_id': 'hw1'}) as LicenseEvent,
        isA<LicenseEvent>(),
      );
      final push = parseLiveFeedEvent({'type': 'push', 'action': 'register', 'hardware_id': 'hw1'}) as PushEvent;
      expect(push.action, 'register');
      expect(push.hardwareId, 'hw1');
    });

    test('an unknown type is dropped rather than guessed at', () {
      expect(parseLiveFeedEvent({'type': 'positions', 'positions': []}), isNull);
    });

    test('a malformed frame is dropped instead of rendered as trading data', () {
      for (final frame in [
        {'type': 'signal', 'symbol': 'US30', 'direction': 'BUY', 'dispatched': true, 'kind': 'entry'}, // no strategy
        {'type': 'signal', 'symbol': 'US30', 'strategy': 'ORB', 'direction': 'LONG', 'dispatched': true, 'kind': 'entry'},
        {'type': 'signal', 'symbol': 'US30', 'strategy': 'ORB', 'direction': 'BUY', 'dispatched': 'yes', 'kind': 'entry'},
        {'type': 'trade_event', 'kind': 'nonsense'},
        {'type': 'trade_event'},
        {'type': 'control', 'action': 'pause', 'paused': 'true'},
        {'type': 'push', 'action': 'register'},
        {'type': 'license', 'service_type': 'EA-ish'},
        <String, dynamic>{},
      ]) {
        expect(parseLiveFeedEvent(frame), isNull, reason: frame.toString());
      }
    });
  });

  group('parseLiveFeedFrame', () {
    test('decodes a JSON object frame', () {
      final event = parseLiveFeedFrame('{"type":"hello","service":"SIGNALS"}');
      expect(event, isA<HelloEvent>());
    });

    test('a keepalive or malformed payload is dropped, not an error', () {
      expect(parseLiveFeedFrame('ping'), isNull);
      expect(parseLiveFeedFrame('not json'), isNull);
      expect(parseLiveFeedFrame('[1,2,3]'), isNull);
      expect(parseLiveFeedFrame(null), isNull);
    });
  });

  group('dedupeKey', () {
    test('two identical frames collapse to one event', () {
      final a = parseLiveFeedEvent(entrySignal())!;
      final b = parseLiveFeedEvent(entrySignal())!;
      expect(a.dedupeKey, b.dedupeKey);
    });

    test('a different ticket is a different event', () {
      final a = parseLiveFeedEvent(entrySignal())!;
      final b = parseLiveFeedEvent({...entrySignal(), 'ticket': 42})!;
      expect(a.dedupeKey, isNot(b.dedupeKey));
    });

    test('the key never contains the licence credential', () {
      final event = parseLiveFeedEvent({
        ...entrySignal(),
        'key': 'PH-SIGNALS-DEADBEEF',
      })!;
      expect(event.dedupeKey, isNot(contains('PH-SIGNALS')));
      expect(event.dedupeKey, isNot(contains('DEADBEEF')));
    });
  });

  test('mock mode reports unconfigured, never a fabricated live feed', () async {
    final service = MockLiveFeedService();
    addTearDown(service.dispose);
    final statuses = <LiveFeedStatus>[];
    final subscription = service.statuses.listen(statuses.add);
    await service.start();
    expect(statuses, [LiveFeedStatus.unconfigured]);
    await subscription.cancel();
  });
}
