import 'dart:async';
import '../domain/scanner_enums.dart';
import '../domain/scanner_setup.dart';
import 'scanner_service.dart';

class MockScannerService implements ScannerService {
  MockScannerService() {
    _setups = List.of(_seed);
    _controller = StreamController<List<ScannerSetup>>.broadcast(
      onListen: () => _controller.add(List.unmodifiable(_setups)),
    );
  }

  late final List<ScannerSetup> _setups;
  late final StreamController<List<ScannerSetup>> _controller;

  void _emit() => _controller.add(List.unmodifiable(_setups));

  @override
  Stream<List<ScannerSetup>> watchSetups({SetupStatus? status}) {
    return _controller.stream.map(
      (all) => status == null ? all : all.where((s) => s.status == status).toList(),
    );
  }

  @override
  Future<ScannerSetup> approve(String setupId, {String? note}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _mutate(setupId, (s) => s.copyWith(status: SetupStatus.approved, notes: note));
  }

  @override
  Future<ScannerSetup> reject(String setupId, {required String reason}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _mutate(setupId, (s) => s.copyWith(status: SetupStatus.rejected, notes: reason));
  }

  @override
  Future<ScannerSetup> update(ScannerSetup setup) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _setups.indexWhere((s) => s.id == setup.id);
    if (index == -1) throw StateError('Setup ${setup.id} not found');
    _setups[index] = setup;
    _emit();
    return setup;
  }

  ScannerSetup _mutate(String id, ScannerSetup Function(ScannerSetup) update) {
    final index = _setups.indexWhere((s) => s.id == id);
    if (index == -1) throw StateError('Setup $id not found');
    final updated = update(_setups[index]);
    _setups[index] = updated;
    _emit();
    return updated;
  }

  static final List<ScannerSetup> _seed = [
    ScannerSetup(
      id: 'setup_001',
      symbol: 'GBPUSD',
      timeframe: 'M30',
      direction: SetupDirection.buy,
      entry: 1.34250,
      stopLoss: 1.33800,
      takeProfits: const [1.35150, 1.36000],
      weeklyBias: Bias.bullish,
      dailyBias: Bias.bullish,
      session: TradingSession.london,
      confluenceScore: 5,
      confluenceMaximum: 6,
      status: SetupStatus.pending,
      detectedAt: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    ScannerSetup(
      id: 'setup_002',
      symbol: 'EURUSD',
      timeframe: 'M30',
      direction: SetupDirection.buy,
      entry: 1.1824,
      stopLoss: 1.1792,
      takeProfits: const [1.1888, 1.1940],
      weeklyBias: Bias.bullish,
      dailyBias: Bias.bullish,
      session: TradingSession.london,
      confluenceScore: 5,
      confluenceMaximum: 6,
      status: SetupStatus.pending,
      detectedAt: DateTime.now().subtract(const Duration(minutes: 40)),
    ),
    ScannerSetup(
      id: 'setup_003',
      symbol: 'XAUUSD',
      timeframe: 'H1',
      direction: SetupDirection.sell,
      entry: 2385.20,
      stopLoss: 2392.50,
      takeProfits: const [2372.00, 2360.00, 2350.00],
      weeklyBias: Bias.bearish,
      dailyBias: Bias.bearish,
      session: TradingSession.newYork,
      confluenceScore: 4,
      confluenceMaximum: 6,
      status: SetupStatus.approved,
      detectedAt: DateTime.now().subtract(const Duration(hours: 3)),
      notes: 'Clean rejection off daily supply.',
    ),
    ScannerSetup(
      id: 'setup_004',
      symbol: 'USDJPY',
      timeframe: 'M15',
      direction: SetupDirection.sell,
      entry: 149.80,
      stopLoss: 150.20,
      takeProfits: const [149.10],
      weeklyBias: Bias.neutral,
      dailyBias: Bias.bearish,
      session: TradingSession.asia,
      confluenceScore: 2,
      confluenceMaximum: 6,
      status: SetupStatus.rejected,
      detectedAt: DateTime.now().subtract(const Duration(hours: 8)),
      notes: 'Confluence too low, no session alignment.',
    ),
  ];
}
