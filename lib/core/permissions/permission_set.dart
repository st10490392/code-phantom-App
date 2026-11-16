import 'permission.dart';

/// A user's effective, per-user permission grants.
///
/// IMPORTANT: this is a client-side UX convenience for hiding/showing
/// modules. It is NOT authorization. Once a real backend exists (Phase 2+),
/// every mutating action must be re-checked server-side — the mobile app
/// must never be treated as the source of truth for what a user is allowed
/// to do. See docs/ARCHITECTURE.md §8.
class PermissionSet {
  const PermissionSet(this.granted);

  final Set<Permission> granted;

  static const PermissionSet none = PermissionSet({});

  static const PermissionSet owner = PermissionSet({
    Permission.scannerAccess,
    Permission.scannerReview,
    Permission.signalsAccess,
    Permission.eaAccess,
    Permission.eaControl,
    Permission.clientAdmin,
    Permission.licenceAdmin,
    Permission.systemAdmin,
    Permission.integrationsManage,
  });

  bool has(Permission permission) => granted.contains(permission);

  bool hasAny(Iterable<Permission> permissions) =>
      permissions.any(granted.contains);

  bool hasAll(Iterable<Permission> permissions) =>
      permissions.every(granted.contains);

  PermissionSet copyWith({Set<Permission>? granted}) =>
      PermissionSet(granted ?? this.granted);

  PermissionSet grant(Permission permission) =>
      PermissionSet({...granted, permission});

  PermissionSet revoke(Permission permission) =>
      PermissionSet(granted.where((p) => p != permission).toSet());

  List<String> toWire() => granted.map((p) => p.wireValue).toList();

  static PermissionSet fromWire(List<dynamic>? values) {
    if (values == null) return PermissionSet.none;
    final perms = values
        .map((v) => Permission.fromWire(v as String))
        .whereType<Permission>()
        .toSet();
    return PermissionSet(perms);
  }
}
