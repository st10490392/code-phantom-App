import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../ea/presentation/ea_providers.dart';
import '../../trading_status/presentation/trading_status_providers.dart';
import '../data/trading_control_service.dart';

/// Whether this build holds the bridge's control token. Read once from secure
/// storage; a client build never has one, so the bridge path is never chosen.
final bridgeControlTokenAvailableProvider = FutureProvider<bool>((ref) async {
  return await ref.watch(bridgeCredentialStorageProvider).readControlToken() != null;
});

/// Which control path this build uses. The Node backend's EA command queue is
/// the only path an ordinary signed-in client can use; the bridge's whole
/// daemon toggle needs an operator credential and is never selected for a
/// client build.
final tradingControlServiceProvider = Provider<TradingControlService>((ref) {
  if (ref.watch(appEnvironmentProvider) == AppEnvironment.mock) {
    return NoOpTradingControlService();
  }
  final tokenAvailable = ref.watch(bridgeControlTokenAvailableProvider).value ?? false;
  if (tokenAvailable) {
    return BridgeTradingControlService(
      credentials: ref.watch(bridgeCredentialStorageProvider),
      client: ref.watch(bridgeClientProvider),
    );
  }
  return EaCommandTradingControlService(ref.watch(eaControlServiceProvider));
});

/// The EA account a control command is scoped to: the caller's own account,
/// which the backend authorizes through `assertEaAccountAccess` (owner or
/// `ea.control` staff). With no EA account there is nothing to control — the
/// honest state, rather than a guessed account id.
final tradingControlTargetProvider = FutureProvider<String?>((ref) async {
  final accounts = await ref.watch(eaAccountListProvider.future);
  if (accounts.isEmpty) return null;
  return accounts.first.accountId;
});

/// Pause/resume state as the *daemon* reports it, from the bridge's `/status`
/// — not inferred from the last command this app sent.
final tradingStateProvider = FutureProvider<bool?>((ref) async {
  final status = await ref.watch(tradingStatusProvider.future);
  return status.paused;
});
