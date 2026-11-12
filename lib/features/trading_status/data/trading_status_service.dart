import '../../../core/config/api_config.dart';
import '../../../core/network/bridge_client.dart';
import '../domain/trading_status.dart';

/// Live MT5 state, read from the trading bridge. Mock mode returns nothing
/// rather than invented positions, so a disconnected/unconfigured bridge can
/// never render as trading data.
abstract interface class TradingStatusService {
  Future<TradingStatus> getStatus();
  Future<List<LivePosition>> getOpenPositions();
  Future<TradingPerformance?> getPerformance();
}

class BridgeTradingStatusService implements TradingStatusService {
  BridgeTradingStatusService(this._client);

  final BridgeClient _client;

  @override
  Future<TradingStatus> getStatus() async {
    return TradingStatus.fromJson(await _client.checkHealth());
  }

  @override
  Future<List<LivePosition>> getOpenPositions() async {
    final body = await _client.get('/positions');
    final rows = body['positions'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(LivePosition.fromJson)
        .whereType<LivePosition>()
        .toList(growable: false);
  }

  @override
  Future<TradingPerformance?> getPerformance() async {
    final body = await _client.get('/analytics');
    return TradingPerformance.fromJson(body['overall']);
  }
}

/// Mock/dev mode: no bridge, and nothing fabricated.
class NoOpTradingStatusService implements TradingStatusService {
  @override
  Future<TradingStatus> getStatus() async => const TradingStatus(
        mt5Connected: null,
        paused: false,
        scanMode: null,
        openPositions: null,
        eaLicensed: null,
        uptimeSeconds: null,
      );

  @override
  Future<List<LivePosition>> getOpenPositions() async => const [];

  @override
  Future<TradingPerformance?> getPerformance() async => null;
}

/// The bridge this build talks to, or `null` when none is configured.
BridgeClient? bridgeClientFromConfig() =>
    ApiConfig.bridgeConfigured ? BridgeClient(baseUrl: ApiConfig.bridgeBaseUrl) : null;

/// How long between dashboard refreshes of live state. Deliberately longer
/// than the signal poll: the bridge is one operator's daemon on a tailnet
/// link, not a public API.
const bridgePollInterval = Duration(seconds: 20);
