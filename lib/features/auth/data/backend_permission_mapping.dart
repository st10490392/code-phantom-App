import '../../../core/permissions/app_role.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/permissions/permission_set.dart';
import '../domain/auth_user.dart';

/// Maps the backend's `permission_code` catalog onto the app's existing
/// [Permission] enum — this is the only permission system the app has;
/// this map is a translation at the edge, not a second one.
///
/// The backend is intentionally more fine-grained than the app's UI-level
/// gates (e.g. it separates `clients.view` from `clients.manage`, where the
/// app currently has one `clientAdmin` gate covering the whole Clients
/// screen). Codes with no UI-level counterpart yet (`scanner.ingest` — a
/// CPT Scanner/service-account capability, never granted to a person using
/// this app; `signals.manage`, `signals.publish`; `notifications.*`) are
/// left unmapped: those modules are still mock-only in this milestone and
/// get their own gate, and their own entry here, when they go live.
const Map<String, Permission> backendPermissionMap = {
  'scanner.view': Permission.scannerAccess,
  'scanner.review': Permission.scannerReview,
  'signals.view': Permission.signalsAccess,
  'ea.view': Permission.eaAccess,
  'ea.control': Permission.eaControl,
  'clients.view': Permission.clientAdmin,
  'clients.manage': Permission.clientAdmin,
  'licences.view': Permission.licenceAdmin,
  'licences.manage': Permission.licenceAdmin,
  'admin.system': Permission.systemAdmin,
  'integrations.manage': Permission.integrationsManage,
};

/// Converts the `permissions: string[]` the backend returns from `/me`
/// into a [PermissionSet]. Unrecognized codes are dropped rather than
/// throwing — a future backend permission this app doesn't understand yet
/// should never break login.
PermissionSet permissionSetFromBackendCodes(Iterable<String> codes) {
  final granted = <Permission>{};
  for (final code in codes) {
    final mapped = backendPermissionMap[code];
    if (mapped != null) granted.add(mapped);
  }
  return PermissionSet(granted);
}

/// Converts account-level service entitlements into the same UI permission
/// gates the app already uses. These are UX visibility grants only; the
/// backend still authorizes every request from its own entitlement records.
PermissionSet permissionSetFromBackendProfile({
  required Iterable<String> permissionCodes,
  required Iterable<String> entitlementCodes,
}) {
  final granted = <Permission>{
    ...permissionSetFromBackendCodes(permissionCodes).granted,
  };

  for (final code in entitlementCodes) {
    if (code.startsWith('scanner.') && code.endsWith('.view')) {
      granted.add(Permission.scannerAccess);
    } else if (code == 'signals.receive') {
      granted.add(Permission.signalsAccess);
    } else if (code == 'ea.monitoring') {
      granted.add(Permission.eaAccess);
    }
  }

  return PermissionSet(granted);
}

/// Highest-privilege-first — used only to collapse the backend's
/// `roles: string[]` (a user can hold more than one) into the single
/// [AppRole] the app's domain model keeps for display and the `isOwner`
/// shortcut. Real per-action authorization always comes from
/// [permissionSetFromBackendCodes], never from this ordering.
const List<AppRole> _rolePriority = [
  AppRole.owner,
  AppRole.admin,
  AppRole.trader,
  AppRole.scannerClient,
  AppRole.signalClient,
  AppRole.eaClient,
  AppRole.client,
  AppRole.internal,
];

AppRole primaryRoleFromBackendCodes(Iterable<String> codes) {
  final roles = codes.map(AppRole.fromWire).toSet();
  for (final role in _rolePriority) {
    if (roles.contains(role)) return role;
  }
  return AppRole.internal;
}

/// Maps a `GET /me` response body — `{ data: { profile, roles,
/// permissions, entitlements } }`, already unwrapped to the inner `data`
/// map — onto the app's [AuthUser]. The backend is authoritative for both
/// staff permissions and paid account entitlements. Older backends that do
/// not yet include `entitlements` remain compatible by treating it as empty.
AuthUser authUserFromApiProfile(Map<String, dynamic> data) {
  final profile = data['profile'] as Map<String, dynamic>;
  final roleCodes = (data['roles'] as List).cast<String>();
  final permissionCodes = (data['permissions'] as List).cast<String>();
  final entitlementCodes =
      ((data['entitlements'] as List?) ?? const <dynamic>[]).cast<String>();
  final email = profile['email'] as String;
  return AuthUser(
    id: profile['id'] as String,
    email: email,
    displayName: (profile['display_name'] as String?) ?? email,
    role: primaryRoleFromBackendCodes(roleCodes),
    permissions: permissionSetFromBackendProfile(
      permissionCodes: permissionCodes,
      entitlementCodes: entitlementCodes,
    ),
    status: profile['status'] as String? ?? 'ACTIVE',
    protected: profile['protected'] as bool? ?? false,
  );
}
