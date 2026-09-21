import 'dart:async';
import '../../scanner/domain/scanner_enums.dart';
import '../domain/signal.dart';
import '../domain/signal_enums.dart';
import '../domain/signal_performance_summary.dart';
import 'signal_service.dart';

class MockSignalService implements SignalService {
  MockSignalService() {
    _signals = List.of(_seed);
    _controller = StreamController<List<Signal>>.broadcast(
      onListen: () => _controller.add(List.unmodifiable(_signals)),
    );
  }

  late final List<Signal> _signals;
  late final StreamController<List<Signal>> _controller;

  @override
  Stream<List<Signal>> watchSignals({SignalStatus? status}) {
    return _controller.stream.map(
      (all) => status == null ? all : all.where((s) => s.status == status).toList(),
    );
  }

  @override
  Future<Signal> updateStatus(String signalId, SignalStatus status) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _signals.indexWhere((s) => s.id == signalId);
    if (index == -1) throw StateError('Signal $signalId not found');
    final current = _signals[index];
    if (!isValidSignalTransition(current.status, status)) {
      throw StateError('Cannot move signal from ${current.status.wireValue} to ${status.wireValue}');
    }
    final updated = current.copyWith(
      status: status,
      closedAt: status.isClosed ? DateTime.now() : null,
    );
    _signals[index] = updated;
    _controller.add(List.unmodifiable(_signals));
    return updated;
  }

  @override
  Future<SignalPerformanceSummary> performanceSummary() async {
    final closed = _signals.where((s) => s.status.isClosed).toList();
    final wins = closed.where((s) => s.result == 'WIN').length;
    final losses = closed.where((s) => s.result == 'LOSS').length;
    final rValues = closed.map((s) => s.rMultiple ?? 0).toList();
    final avgR = rValues.isEmpty ? 0.0 : rValues.reduce((a, b) => a + b) / rValues.length;
    return SignalPerformanceSummary(
      totalSignals: closed.length,
      wins: wins,
      losses: losses,
      winRatePercent: closed.isEmpty ? 0 : (wins / closed.length) * 100,
      averageRMultiple: avgR,
    );
  }

  static final List<Signal> _seed = [
    Signal(
      id: 'signal_001',
      setupId: 'setup_003',
      symbol: 'XAUUSD',
      direction: SetupDirection.sell,
      entry: 2385.20,
      stopLoss: 2392.50,
      takeProfits: const [2372.00, 2360.00, 2350.00],
      status: SignalStatus.tp1Hit,
      session: TradingSession.newYork,
      openedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Signal(
      id: 'signal_002',
      symbol: 'GBPJPY',
      direction: SetupDirection.buy,
      entry: 191.20,
      stopLoss: 190.60,
      takeProfits: const [192.10, 192.90],
      status: SignalStatus.closed,
      session: TradingSession.london,
      openedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      closedAt: DateTime.now().subtract(const Duration(hours: 20)),
      result: 'WIN',
      rMultiple: 2.4,
    ),
    Signal(
      id: 'signal_003',
      symbol: 'AUDUSD',
      direction: SetupDirection.sell,
      entry: 0.6620,
      stopLoss: 0.6648,
      takeProfits: const [0.6580],
      status: SignalStatus.stopped,
      session: TradingSession.asia,
      openedAt: DateTime.now().subtract(const Duration(days: 2)),
      closedAt: DateTime.now().subtract(const Duration(days: 1, hours: 18)),
      result: 'LOSS',
      rMultiple: -1.0,
    ),
  ];
}
