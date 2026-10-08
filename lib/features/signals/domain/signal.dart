import 'signal_enums.dart';

class Signal {
  const Signal({
    required this.id,
    this.setupId,
    this.timeframe,
    required this.symbol,
    required this.direction,
    required this.entry,
    required this.stopLoss,
    required this.takeProfits,
    required this.status,
    required this.session,
    required this.openedAt,
    this.closedAt,
    this.result,
    this.rMultiple,
    this.notes,
  });

  final String id;
  final String? setupId;
  final String? timeframe;
  final String symbol;
  final SetupDirection direction;
  final double entry;
  final double stopLoss;
  final List<double> takeProfits;
  final SignalStatus status;
  final TradingSession session;
  final DateTime openedAt;
  final DateTime? closedAt;

  /// e.g. "WIN", "LOSS", "BREAK_EVEN" — free-form until a backend contract exists.
  final String? result;
  final double? rMultiple;
  final String? notes;

  Signal copyWith(
      {SignalStatus? status,
      DateTime? closedAt,
      String? result,
      double? rMultiple,}) {
    return Signal(
      id: id,
      setupId: setupId,
      timeframe: timeframe,
      symbol: symbol,
      direction: direction,
      entry: entry,
      stopLoss: stopLoss,
      takeProfits: takeProfits,
      status: status ?? this.status,
      session: session,
      openedAt: openedAt,
      closedAt: closedAt ?? this.closedAt,
      result: result ?? this.result,
      rMultiple: rMultiple ?? this.rMultiple,
      notes: notes,
    );
  }
}
