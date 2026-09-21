import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/scanner_enums.dart';
import '../domain/scanner_setup.dart';
import 'scanner_service.dart';

class MockScannerService implements ScannerService {
  MockScannerService() {
    _setups = List.of(_seed);
  }

  late final List<ScannerSetup> _setups;

  /// A broadcast "something changed" ping — deliberately carries no payload.
  /// Each `watchSetups` subscriber re-filters `_setups` fresh from its own
  /// `async*` generator (see below), so every new listener gets the current
  /// snapshot immediately regardless of how many other listeners (other
  /// tabs, the dashboard, ...) are already subscribed. A plain
  /// `broadcast(onListen: ...)` can't do this: `onListen` only fires on the
  /// controller's 0→1 listener transition, so a second concurrent filtered
  /// view (e.g. the Scanner screen's other tabs, all mounted at once by
  /// `TabBarView`) would never receive its initial data. See
  /// docs/ARCHITECTURE.md's "Mock service rule".
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _emit() => _changes.add(null);

  List<ScannerSetup> _filtered(SetupStatus? status) {
    final all = List<ScannerSetup>.unmodifiable(_setups);
    return status == null ? all : all.where((s) => s.status == status).toList();
  }

  @override
  Stream<List<ScannerSetup>> watchSetups({SetupStatus? status}) async* {
    yield _filtered(status);
    yield* _changes.stream.map((_) => _filtered(status));
  }

  @override
  Future<ScannerSetup?> getSetupById(String id) async {
    for (final s in _setups) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<ScannerSetup> approve(String setupId, {String? note, String? reviewedBy}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _transition(
      setupId,
      SetupStatus.approved,
      (s) => s.copyWith(
        status: SetupStatus.approved,
        notes: note,
        reviewedAt: DateTime.now(),
        reviewedBy: reviewedBy,
      ),
    );
  }

  @override
  Future<ScannerSetup> reject(String setupId, {required String reason, String? reviewedBy}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _transition(
      setupId,
      SetupStatus.rejected,
      (s) => s.copyWith(
        status: SetupStatus.rejected,
        rejectionReason: reason,
        reviewedAt: DateTime.now(),
        reviewedBy: reviewedBy,
      ),
    );
  }

  @override
  Future<ScannerSetup> update(ScannerSetup setup) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final index = _setups.indexWhere((s) => s.id == setup.id);
    if (index == -1) throw StateError('Setup ${setup.id} not found');
    final original = _setups[index];
    if (original.status != SetupStatus.pending) {
      throw StateError('Only a pending setup can be edited (${original.id} is ${original.status.wireValue})');
    }

    final materialChange = original.entry != setup.entry ||
        original.stopLoss != setup.stopLoss ||
        !listEquals(original.takeProfits, setup.takeProfits) ||
        original.direction != setup.direction ||
        original.timeframe != setup.timeframe;

    final updated = materialChange ? setup.copyWith(editedBeforeApproval: true) : setup;
    _setups[index] = updated;
    _emit();
    return updated;
  }

  ScannerSetup _transition(
    String id,
    SetupStatus newStatus,
    ScannerSetup Function(ScannerSetup) apply,
  ) {
    final index = _setups.indexWhere((s) => s.id == id);
    if (index == -1) throw StateError('Setup $id not found');
    final current = _setups[index];
    if (!isValidSetupTransition(current.status, newStatus)) {
      throw StateError(
        'Cannot move setup from ${current.status.wireValue} to ${newStatus.wireValue}',
      );
    }
    final updated = apply(current);
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
      reviewedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 40)),
      reviewedBy: 'Ripfumelo (Owner)',
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
      rejectionReason: 'Invalid structure',
      reviewedAt: DateTime.now().subtract(const Duration(hours: 7, minutes: 30)),
      reviewedBy: 'Ripfumelo (Owner)',
    ),
    ScannerSetup(
      id: 'setup_005',
      symbol: 'US100',
      timeframe: 'M15',
      direction: SetupDirection.buy,
      entry: 19850.0,
      stopLoss: 19780.0,
      takeProfits: const [19950.0, 20050.0],
      weeklyBias: Bias.bullish,
      dailyBias: Bias.bullish,
      session: TradingSession.newYork,
      confluenceScore: 6,
      confluenceMaximum: 6,
      status: SetupStatus.pending,
      detectedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    ScannerSetup(
      id: 'setup_006',
      symbol: 'EURUSD',
      timeframe: 'H1',
      direction: SetupDirection.sell,
      entry: 1.0950,
      stopLoss: 1.0985,
      takeProfits: const [1.0900],
      weeklyBias: Bias.neutral,
      dailyBias: Bias.bearish,
      session: TradingSession.london,
      confluenceScore: 3,
      confluenceMaximum: 6,
      status: SetupStatus.pending,
      detectedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
    ),
    ScannerSetup(
      id: 'setup_007',
      symbol: 'XAUUSD',
      timeframe: 'M30',
      direction: SetupDirection.buy,
      entry: 2410.50,
      stopLoss: 2398.00,
      takeProfits: const [2428.00, 2440.00],
      weeklyBias: Bias.bullish,
      dailyBias: Bias.bullish,
      session: TradingSession.newYork,
      confluenceScore: 5,
      confluenceMaximum: 6,
      status: SetupStatus.approved,
      detectedAt: DateTime.now().subtract(const Duration(hours: 5)),
      reviewedAt: DateTime.now().subtract(const Duration(hours: 4, minutes: 45)),
      reviewedBy: 'Ops Admin',
    ),
    ScannerSetup(
      id: 'setup_008',
      symbol: 'GBPUSD',
      timeframe: 'H4',
      direction: SetupDirection.sell,
      entry: 1.2650,
      stopLoss: 1.2705,
      takeProfits: const [1.2580],
      weeklyBias: Bias.bearish,
      dailyBias: Bias.neutral,
      session: TradingSession.london,
      confluenceScore: 2,
      confluenceMaximum: 6,
      status: SetupStatus.rejected,
      detectedAt: DateTime.now().subtract(const Duration(hours: 14)),
      rejectionReason: 'Poor R:R',
      reviewedAt: DateTime.now().subtract(const Duration(hours: 13, minutes: 20)),
      reviewedBy: 'Ops Admin',
    ),
    ScannerSetup(
      id: 'setup_009',
      symbol: 'USDJPY',
      timeframe: 'H1',
      direction: SetupDirection.buy,
      entry: 151.20,
      stopLoss: 150.60,
      takeProfits: const [151.90, 152.50],
      weeklyBias: Bias.bullish,
      dailyBias: Bias.bullish,
      session: TradingSession.asia,
      confluenceScore: 4,
      confluenceMaximum: 6,
      status: SetupStatus.pending,
      detectedAt: DateTime.now().subtract(const Duration(minutes: 55)),
    ),
  ];
}
