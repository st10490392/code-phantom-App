import 'app_role.dart';
import 'permission.dart';
import 'permission_set.dart';

/// Default `PermissionSet` a role starts with when a new client is
/// provisioned. These are *defaults only* — an OWNER/ADMIN can grant or
/// revoke individual permissions per user afterwards (see
/// docs/ARCHITECTURE.md §5). `INTERNAL` intentionally starts with nothing;
/// every grant for internal/test/friends-and-family accounts is explicit.
PermissionSet defaultPermissionsFor(AppRole role) {
  switch (role) {
    case AppRole.owner:
      return PermissionSet.owner;
    case AppRole.admin:
      return const PermissionSet({
        Permission.scannerAccess,
        Permission.scannerReview,
        Permission.signalsAccess,
        Permission.clientAdmin,
        Permission.licenceAdmin,
        Permission.systemAdmin,
      });
    case AppRole.trader:
      return const PermissionSet({
        Permission.scannerAccess,
        Permission.signalsAccess,
      });
    case AppRole.scannerClient:
      return const PermissionSet({Permission.scannerAccess});
    case AppRole.signalClient:
      return const PermissionSet({Permission.signalsAccess});
    case AppRole.eaClient:
      return const PermissionSet({Permission.eaAccess});
    case AppRole.internal:
      return PermissionSet.none;
  }
}
