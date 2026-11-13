import '../../../core/config/api_config.dart';
import '../../../core/network/app_exceptions.dart';
import '../../../core/network/bridge_client.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/permissions/permission_set.dart';
import '../../../core/storage/bridge_credentials.dart';
import '../../ea/data/ea_services.dart';

/// Pause/resume of live trading.
///
/// Two backends, two different capabilities, and this client never pretends
/// they are the same:
///
/// - `EaCommandTradingControlService` reuses the existing EA control contract
///   (`ApiEAService` → `POST /ea/accounts/:id/commands`, allow-listed
///   `PAUSE_TRADING` / `RESUME_TRADING`). The backend gates it with
///   `ea.control`, so an ordinary client gets 403 — the client-side check in
///   `canControlTrading` is UX, never authorization.
/// - `BridgeTradingControlService` talks to the FastAPI bridge's
///   `POST /control/toggle`, which requires the bridge's own `scope=control`
///   JWT. A phone never holds one, so this refuses before any network call
///   rather than presenting a toggle that cannot be authorized.
abstract interface class TradingControlService {
  Future<void> pause({required String accountId});
  Future<void> resume({required String accountId});
}

/// Permission codes that authorize an EA control command, mirroring the
/// backend's `requirePermission(PERMISSIONS.EA_CONTROL)` gate. OWNER holds
/// every permission, exactly as the backend treats it.
const List<Permission> tradingControlPermissions = [Permission.eaControl];

bool canControlTrading(PermissionSet permissions, {required bool isOwner}) =>
    isOwner || permissions.hasAny(tradingControlPermissions);

/// The dashboard's control surface, on the EA command contract the app
/// already speaks. Nothing here claims the daemon changed state — the live
/// state is read from the bridge's own `/status`.
class EaCommandTradingControlService implements TradingControlService {
  EaCommandTradingControlService(this._control);

  final EAControlService _control;

  @override
  Future<void> pause({required String accountId}) => _control.pauseTrading(accountId);

  @override
  Future<void> resume({required String accountId}) => _control.resumeTrading(accountId);
}

/// Refuses every control attempt from a client build, and only ever attempts a
/// bridge toggle when this build genuinely holds the bridge's control token.
class BridgeTradingControlService implements TradingControlService {
  BridgeTradingControlService({required this.credentials, required this.client});

  final BridgeCredentialStorage credentials;
  final BridgeClient? client;

  Future<void> _toggle(String action) async {
    if (client == null || !ApiConfig.bridgeConfigured) {
      throw const AuthorizationException('No trading bridge is configured for this build.');
    }
    final token = await credentials.readControlToken();
    if (token == null) {
      throw const AuthorizationException(
        'Trading control requires the bridge operator credential; this app does not hold one.',
      );
    }
    await BridgeClient(baseUrl: ApiConfig.bridgeBaseUrl, controlToken: token).post(
      '/control/toggle',
      body: {'action': action},
      requiresControlToken: true,
    );
  }

  /// `accountId` is unused here: the bridge toggles the whole daemon, which is
  /// why it needs an operator credential rather than an account-scoped one.
  @override
  Future<void> pause({required String accountId}) => _toggle('pause');

  @override
  Future<void> resume({required String accountId}) => _toggle('resume');
}

/// Mock/dev mode: no control path exists, and none is pretended.
class NoOpTradingControlService implements TradingControlService {
  @override
  Future<void> pause({required String accountId}) async =>
      throw const AuthorizationException('Trading control is not available in mock mode.');

  @override
  Future<void> resume({required String accountId}) async =>
      throw const AuthorizationException('Trading control is not available in mock mode.');
}

/// Whether this build may offer the control surface at all. Off unless the
/// build opts in via `--dart-define=TRADING_CONTROLS_ENABLED=true`; the
/// backend authorizes the action regardless.
bool tradingControlOffered(bool isOwner, PermissionSet permissions) =>
    ApiConfig.tradingControlsEnabled && canControlTrading(permissions, isOwner: isOwner);
