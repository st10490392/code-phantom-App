import 'package:flutter/material.dart';
import '../../features/auth/domain/auth_user.dart';
import '../permissions/permission.dart';

/// Describes the production-ready primary navigation areas. `permission ==
/// null` means always visible (Dashboard, Notifications, Settings).
class NavDestination {
  const NavDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.permission,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Permission? permission;
}

const List<NavDestination> primaryNavDestinations = [
  NavDestination(
    path: '/dashboard',
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  NavDestination(
    path: '/scanner',
    label: 'Scanner',
    icon: Icons.radar_outlined,
    selectedIcon: Icons.radar,
    permission: Permission.scannerAccess,
  ),
  NavDestination(
    path: '/signals',
    label: 'Signals',
    icon: Icons.show_chart_outlined,
    selectedIcon: Icons.show_chart,
    permission: Permission.signalsAccess,
  ),
  NavDestination(
    path: '/ea',
    label: 'EA',
    icon: Icons.memory_outlined,
    selectedIcon: Icons.memory,
    permission: Permission.eaAccess,
  ),
  NavDestination(
    path: '/licences',
    label: 'Keys',
    icon: Icons.vpn_key_outlined,
    selectedIcon: Icons.vpn_key,
    permission: Permission.licenceAdmin,
  ),
  NavDestination(
    path: '/notifications',
    label: 'Alerts',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
  ),
  NavDestination(
    path: '/settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

/// Filters [primaryNavDestinations] down to what [user] may see: items with
/// no [NavDestination.permission] are always visible, OWNER sees everything,
/// everyone else needs the matching grant on their own [AuthUser.permissions].
///
/// This is the single source of truth for "module visibility" — both
/// [AppShell] (bottom nav) and anything else that needs to know which
/// modules a user can reach should call this rather than re-deriving the
/// same filter.
List<NavDestination> visibleNavDestinationsFor(AuthUser? user) {
  return primaryNavDestinations.where((d) {
    if (d.permission == null) return true;
    if (user == null) return false;
    if (user.isOwner) return true;
    return user.permissions.has(d.permission!);
  }).toList();
}
