import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission.dart';
import 'package:code_phantom_app/core/permissions/permission_set.dart';
import 'package:code_phantom_app/core/permissions/role_defaults.dart';
import 'package:code_phantom_app/core/routing/nav_destination.dart';
import 'package:code_phantom_app/features/auth/domain/auth_user.dart';

AuthUser _userWith(AppRole role, PermissionSet permissions) => AuthUser(
      id: 'u_${role.name}',
      email: '${role.name}@codephantom.dev',
      displayName: role.name,
      role: role,
      permissions: permissions,
    );

void main() {
  group('visibleNavDestinationsFor — module visibility', () {
    test('signed out sees only the always-visible destinations', () {
      final visible = visibleNavDestinationsFor(null);
      expect(visible.map((d) => d.path), ['/dashboard', '/notifications', '/settings']);
    });

    test('OWNER sees every destination regardless of stored grants', () {
      final owner = _userWith(AppRole.owner, PermissionSet.none);
      final visible = visibleNavDestinationsFor(owner);
      expect(visible.length, primaryNavDestinations.length);
      expect(visible.map((d) => d.path), primaryNavDestinations.map((d) => d.path));
    });

    test('SCANNER_CLIENT sees Dashboard, Scanner, Alerts, Settings only', () {
      final client = _userWith(AppRole.scannerClient, defaultPermissionsFor(AppRole.scannerClient));
      final paths = visibleNavDestinationsFor(client).map((d) => d.path).toSet();
      expect(paths, {'/dashboard', '/scanner', '/notifications', '/settings'});
      expect(paths.contains('/signals'), isFalse);
      expect(paths.contains('/ea'), isFalse);
      expect(paths.contains('/clients'), isFalse);
      expect(paths.contains('/licences'), isFalse);
    });

    test('EA_CLIENT sees Dashboard, EA, Alerts, Settings only', () {
      final client = _userWith(AppRole.eaClient, defaultPermissionsFor(AppRole.eaClient));
      final paths = visibleNavDestinationsFor(client).map((d) => d.path).toSet();
      expect(paths, {'/dashboard', '/ea', '/notifications', '/settings'});
    });

    test('a user with an independently-granted permission sees that module '
        'even though their role does not default to it', () {
      final trader = _userWith(
        AppRole.trader,
        defaultPermissionsFor(AppRole.trader).grant(Permission.clientAdmin),
      );
      final paths = visibleNavDestinationsFor(trader).map((d) => d.path).toSet();
      expect(paths.contains('/clients'), isTrue,
          reason: 'effective permissions, not role defaults, drive visibility',);
    });

    test('ADMIN does not see EA (not in its default grant set)', () {
      final admin = _userWith(AppRole.admin, defaultPermissionsFor(AppRole.admin));
      final paths = visibleNavDestinationsFor(admin).map((d) => d.path).toSet();
      expect(paths.contains('/ea'), isFalse);
      expect(paths.contains('/clients'), isTrue);
      expect(paths.contains('/licences'), isTrue);
    });
  });
}
