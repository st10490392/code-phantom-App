import '../domain/ea_account.dart';
import '../domain/ea_enums.dart';

/// External-engine boundary: the CodePhantom EA runs on a VPS, never inside
/// this app. These interfaces are the ONLY contact point — no order
/// execution or strategy logic is implemented here (see brief). Phase 4
/// wires real implementations behind these same contracts.
abstract class EAService {
  Stream<EAAccount> watchAccount(String accountId);

  /// OWNER/ADMIN view across multiple client accounts.
  Future<List<EAAccount>> listAccounts();
}

abstract class EAAccountService {
  Future<EAAccount> getAccount(String accountId);
}

abstract class EAControlService {
  Future<void> pauseTrading(String accountId);
  Future<void> resumeTrading(String accountId);
  Future<void> setRiskMode(String accountId, RiskMode mode);
  Future<void> setRiskPercentage(String accountId, double percentage);
  Future<void> disableNewEntries(String accountId);
  Future<void> emergencyStop(String accountId);
}
