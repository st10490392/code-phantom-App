import 'package:flutter/material.dart';
import '../permissions/permission.dart';

/// Describes one of the 8 primary nav areas from the brief. `permission ==
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
    path: '/clients',
    label: 'Clients',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
    permission: Permission.clientAdmin,
  ),
  NavDestination(
    path: '/licences',
    label: 'Licences',
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
