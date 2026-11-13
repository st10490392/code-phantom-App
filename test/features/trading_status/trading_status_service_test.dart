import 'dart:convert';
import 'dart:typed_data';

import 'package:code_phantom_app/core/network/bridge_client.dart';
import 'package:code_phantom_app/features/trading_status/data/trading_status_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canned bridge responses. Bodies are the exact shapes `api_server.py`
/// returns: bare JSON, no `data` envelope.
class _BridgeAdapter implements HttpClientAdapter {
  _BridgeAdapter(this.handler);
  final Map<String, dynamic> Function(String path) handler;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(o.path);
    return ResponseBody.fromString(
      jsonEncode(handler(o.path)),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

BridgeClient _client(Map<String, dynamic> Function(String path) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'http://bridge.test/api/v1'));
  dio.httpClientAdapter = _BridgeAdapter(handler);
  return BridgeClient(baseUrl: 'http://bridge.test/api/v1', dio: dio);
}

const statusBody = {
  'service': 'phantom-v2',
  'daemon': 'signal_pipeline',
  'mt5_ipc': 'DISCONNECTED',
  'licensed': false,
  'paused': true,
  'scan_mode': 'live',
  'open_positions': 0,
  'uptime_seconds': 42.5,
};

void main() {
  test('status maps the bridge fields without inventing any', () async {
    final status = await BridgeTradingStatusService(_client((p) => p == '/status' ? statusBody : const {})).getStatus();
    expect(status.mt5Connected, isFalse);
    expect(status.paused, isTrue);
    expect(status.scanMode, 'live');
    expect(status.openPositions, 0);
    expect(status.eaLicensed, isFalse);
    expect(status.uptimeSeconds, 42.5);
  });

  test('a missing mt5_ipc field is unknown, not "disconnected"', () async {
    final status = await BridgeTradingStatusService(_client((p) => {'paused': false})).getStatus();
    expect(status.mt5Connected, isNull);
    expect(status.openPositions, isNull);
  });

  test('positions carry the live R only when MT5 answered a tick', () async {
    final client = _client((p) {
      if (p != '/positions') return const {};
      return {
        'count': 2,
        'positions': [
          {
            'ticket': 11,
            'symbol': 'US30',
            'strategy': 'ORB',
            'asset_class': 'Indices',
            'direction': 'BUY',
            'entry': 43100.0,
            'sl': 43050.0,
            'tp': 43200.0,
            'volume': 0.10,
            'be_activated': true,
            'partial_closed': false,
            'floating_r': 1.4,
          },
          {
            'ticket': 12,
            'symbol': 'EURUSD',
            'strategy': 'Z_SCORE',
            'direction': 'SELL',
            'entry': 1.09,
            'sl': 1.10,
            'tp': 1.07,
            'volume': 0.5,
            'be_activated': false,
            'partial_closed': false,
            // MT5 disconnected: the bridge reports no live price.
            'floating_r': null,
          },
          // Malformed row: dropped, never rendered as a position.
          {'ticket': 13},
        ],
      };
    });
    final positions = await BridgeTradingStatusService(client).getOpenPositions();
    expect(positions, hasLength(2));
    expect(positions.first.hasLivePrice, isTrue);
    expect(positions.first.floatingR, 1.4);
    expect(positions.first.breakEvenActive, isTrue);
    expect(positions.last.hasLivePrice, isFalse);
    expect(positions.last.assetClass, isNull);
  });

  test('analytics keeps an unbounded profit factor as null, not zero', () async {
    final client = _client((p) {
      if (p != '/analytics') return const {};
      return {
        'overall': {
          'total_trades': 8,
          'win_rate_pct': 62.5,
          'net_r': 4.1,
          'max_drawdown_r': 1.2,
          // The bridge sends null for an unbounded profit factor.
          'profit_factor': null,
        },
        'by_strategy': {'ORB': {'total_trades': 3}},
      };
    });
    final performance = await BridgeTradingStatusService(client).getPerformance();
    expect(performance?.totalTrades, 8);
    expect(performance?.profitFactor, isNull);
    expect(performance?.netR, 4.1);
  });

  test('an empty position list is reported as empty, not fabricated', () async {
    final positions = await BridgeTradingStatusService(_client((p) => {'count': 0, 'positions': []}))
        .getOpenPositions();
    expect(positions, isEmpty);
  });

  test('no bridge configured means no trading data is claimed', () async {
    expect(bridgeClientFromConfig(), isNull);
    expect(await NoOpTradingStatusService().getOpenPositions(), isEmpty);
    expect(await NoOpTradingStatusService().getPerformance(), isNull);
    final status = await NoOpTradingStatusService().getStatus();
    expect(status.mt5Connected, isNull);
    expect(status.eaLicensed, isNull);
  });
}
