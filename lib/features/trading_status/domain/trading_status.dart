/// Live daemon state from the trading bridge's `GET /api/v1/status`.
///
/// Every field is read from the bridge's own response; nothing here is
/// inferred. A missing or malformed field is `null` and renders as
/// "unavailable", never as a plausible-looking default.
class TradingStatus {
  const TradingStatus({
    required this.mt5Connected,
    required this.paused,
    required this.scanMode,
    required this.openPositions,
    required this.eaLicensed,
    required this.uptimeSeconds,
  });

  /// `mt5_ipc` — `CONNECTED`/`DISCONNECTED`. `null` means the bridge did not
  /// report it, which is different from "disconnected".
  final bool? mt5Connected;
  final bool paused;
  final String? scanMode;
  final int? openPositions;
  final bool? eaLicensed;
  final double? uptimeSeconds;

  factory TradingStatus.fromJson(Map<String, dynamic> json) => TradingStatus(
        mt5Connected: json['mt5_ipc'] == 'CONNECTED'
            ? true
            : json['mt5_ipc'] == 'DISCONNECTED'
                ? false
                : null,
        paused: json['paused'] as bool? ?? false,
        scanMode: json['scan_mode'] as String?,
        openPositions: json['open_positions'] is int ? json['open_positions'] as int : null,
        eaLicensed: json['licensed'] as bool?,
        uptimeSeconds: json['uptime_seconds'] is num ? (json['uptime_seconds'] as num).toDouble() : null,
      );
}

/// One live MT5 position from `GET /api/v1/positions`, plus the daemon's
/// lifecycle state for it.
///
/// There is deliberately no synthetic current price or currency P&L: the
/// bridge reports `floating_r` only when MT5 answers a tick, and a null there
/// is shown as "unavailable" rather than computed client-side.
class LivePosition {
  const LivePosition({
    required this.ticket,
    required this.symbol,
    required this.strategy,
    required this.assetClass,
    required this.direction,
    required this.entry,
    required this.stopLoss,
    required this.takeProfit,
    required this.volume,
    required this.breakEvenActive,
    required this.partiallyClosed,
    this.floatingR,
  });

  final int ticket;
  final String symbol;
  final String strategy;
  final String? assetClass;
  final String direction;
  final double entry;
  final double stopLoss;
  final double takeProfit;
  final double volume;
  final bool breakEvenActive;
  final bool partiallyClosed;

  /// Favorable R-multiple against the live tick; `null` when MT5 is
  /// disconnected, which is the honest "no price right now" state.
  final double? floatingR;

  static LivePosition? fromJson(Map<String, dynamic> json) {
    final ticket = json['ticket'];
    final symbol = json['symbol'];
    final entry = _number(json['entry']);
    if (ticket is! int || symbol is! String || entry == null) return null;
    final sl = _number(json['sl']);
    final tp = _number(json['tp']);
    final volume = _number(json['volume']);
    if (sl == null || tp == null || volume == null) return null;
    final direction = json['direction'];
    if (direction != 'BUY' && direction != 'SELL') return null;
    return LivePosition(
      ticket: ticket,
      symbol: symbol,
      strategy: json['strategy'] is String ? json['strategy'] as String : 'unknown',
      assetClass: json['asset_class'] is String ? json['asset_class'] as String : null,
      direction: direction,
      entry: entry,
      stopLoss: sl,
      takeProfit: tp,
      volume: volume,
      breakEvenActive: json['be_activated'] == true,
      partiallyClosed: json['partial_closed'] == true,
      floatingR: _number(json['floating_r']),
    );
  }

  bool get hasLivePrice => floatingR != null;
}

/// R-based performance from `GET /api/v1/analytics`, per segment. The bridge
/// sends `profit_factor: null` for an unbounded profit factor — that is
/// "unbounded", not zero, so it stays null here.
class TradingPerformance {
  const TradingPerformance({
    required this.totalTrades,
    required this.winRatePercent,
    required this.netR,
    required this.maxDrawdownR,
    this.profitFactor,
  });

  final int totalTrades;
  final double winRatePercent;
  final double netR;
  final double maxDrawdownR;
  final double? profitFactor;

  static TradingPerformance? fromJson(Object? json) {
    if (json is! Map) return null;
    final total = json['total_trades'];
    return TradingPerformance(
      totalTrades: total is int ? total : 0,
      winRatePercent: _number(json['win_rate_pct']) ?? 0,
      netR: _number(json['net_r']) ?? 0,
      maxDrawdownR: _number(json['max_drawdown_r']) ?? 0,
      profitFactor: _number(json['profit_factor']),
    );
  }
}

double? _number(Object? value) => value is num ? value.toDouble() : null;
