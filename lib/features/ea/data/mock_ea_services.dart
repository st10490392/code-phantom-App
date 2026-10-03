import 'dart:async';
import '../domain/ea_account.dart';
import '../domain/ea_enums.dart';
import 'ea_services.dart';

class _MockEAStore {
  _MockEAStore._();
  static final _MockEAStore instance = _MockEAStore._();

  final Map<String, EAAccount> accounts = {
    for (final a in _seed) a.accountId: a,
  };

  final Map<String, StreamController<EAAccount>> _controllers = {};

  StreamController<EAAccount> controllerFor(String accountId) {
    return _controllers.putIfAbsent(
      accountId,
      () => StreamController<EAAccount>.broadcast(
        // See docs/ARCHITECTURE.md "Mock service rule" — must be deferred.
        onListen: () => scheduleMicrotask(() {
          final account = accounts[accountId];
          if (account != null) _controllers[accountId]!.add(account);
        }),
      ),
    );
  }

  void update(String accountId, EAAccount Function(EAAccount) mutate) {
    final current = accounts[accountId];
    if (current == null) throw StateError('EA account $accountId not found');
    final updated = mutate(current);
    accounts[accountId] = updated;
    controllerFor(accountId).add(updated);
  }

  static final List<EAAccount> _seed = [
    EAAccount(
      accountId: 'ea_001',
      nickname: 'FTMO Challenge #1',
      broker: 'FTMO',
      status: EAConnectionStatus.online,
      tradingEnabled: true,
      riskMode: RiskMode.prop,
      riskPercentage: 1.0,
      balance: 10000,
      equity: 10125,
      dailyProfit: 125,
      dailyDrawdown: 0.7,
      weeklyDrawdown: 1.4,
      openTrades: 2,
      lastHeartbeat: DateTime.now().subtract(const Duration(seconds: 40)),
      serverStatus: 'VPS-LON-02 · Healthy',
    ),
    EAAccount(
      accountId: 'ea_002',
      nickname: 'Live — Personal',
      broker: 'IC Markets',
      status: EAConnectionStatus.offline,
      tradingEnabled: false,
      riskMode: RiskMode.moderate,
      riskPercentage: 0.5,
      balance: 4200,
      equity: 4110,
      dailyProfit: -90,
      dailyDrawdown: 2.1,
      openTrades: 0,
      lastHeartbeat: DateTime.now().subtract(const Duration(hours: 6)),
      serverStatus: 'VPS-JHB-01 · Unreachable',
    ),
  ];
}

class MockEAService implements EAService {
  @override
  Stream<EAAccount> watchAccount(String accountId) =>
      _MockEAStore.instance.controllerFor(accountId).stream;

  @override
  Future<List<EAAccount>> listAccounts() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _MockEAStore.instance.accounts.values.toList();
  }
}

class MockEAAccountService implements EAAccountService {
  @override
  Future<EAAccount> getAccount(String accountId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final account = _MockEAStore.instance.accounts[accountId];
    if (account == null) throw StateError('EA account $accountId not found');
    return account;
  }
}

class MockEAControlService implements EAControlService {
  @override
  Future<void> pauseTrading(String accountId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _MockEAStore.instance.update(accountId, (a) => a.copyWith(tradingEnabled: false));
  }

  @override
  Future<void> resumeTrading(String accountId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _MockEAStore.instance.update(accountId, (a) => a.copyWith(tradingEnabled: true));
  }

  @override
  Future<void> setRiskMode(String accountId, RiskMode mode) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _MockEAStore.instance.update(accountId, (a) => a.copyWith(riskMode: mode));
  }

  @override
  Future<void> setRiskPercentage(String accountId, double percentage) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _MockEAStore.instance.update(accountId, (a) => a.copyWith(riskPercentage: percentage));
  }

  @override
  Future<void> disableNewEntries(String accountId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Mock: modelled the same as pausing new trading in Phase 1.
    _MockEAStore.instance.update(accountId, (a) => a.copyWith(tradingEnabled: false));
  }

  @override
  Future<void> emergencyStop(String accountId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _MockEAStore.instance.update(
      accountId,
      (a) => a.copyWith(tradingEnabled: false, status: EAConnectionStatus.offline),
    );
  }
}
