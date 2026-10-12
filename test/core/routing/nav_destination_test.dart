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
      expect(
        visible.map((d) => d.path),
        ['/dashboard', '/notifications', '/settings'],
      );
    });

    test('OWNER sees shipped destinations, with V5 off by default', () {
      final owner = _userWith(AppRole.owner, PermissionSet.none);
      final visible = visibleNavDestinationsFor(owner);
      expect(visible.map((d) => d.path), isNot(contains('/enkidu-shadow')));
      expect(visible.length, primaryNavDestinations.length - 1);
    });

    test('V5 destination is OWNER only when the local flag is enabled', () {
      final owner = _userWith(AppRole.owner, PermissionSet.none);
      final customer = _userWith(AppRole.client, PermissionSet.none);
      expect(
        visibleNavDestinationsFor(owner, enkiduShadowEnabled: true)
            .map((d) => d.path),
        contains('/enkidu-shadow'),
      );
      expect(
        visibleNavDestinationsFor(customer, enkiduShadowEnabled: true)
            .map((d) => d.path),
        isNot(contains('/enkidu-shadow')),
      );
    });

    test('SCANNER_CLIENT sees Dashboard, Scanner, Alerts, Settings only', () {
      final client = _userWith(
        AppRole.scannerClient,
        defaultPermissionsFor(AppRole.scannerClient),
      );
      final paths =
          visibleNavDestinationsFor(client).map((d) => d.path).toSet();
      expect(paths, {'/dashboard', '/scanner', '/notifications', '/settings'});
      expect(paths.contains('/signals'), isFalse);
      expect(paths.contains('/ea'), isFalse);
    });

    test('EA_CLIENT retains the deployed read-only EA monitor', () {
      final client =
          _userWith(AppRole.eaClient, defaultPermissionsFor(AppRole.eaClient));
      final paths =
          visibleNavDestinationsFor(client).map((d) => d.path).toSet();
      expect(paths, {'/dashboard', '/ea', '/notifications', '/settings'});
    });

    test(
        'a user with an independently-granted permission sees that module '
        'even though their role does not default to it', () {
      final scannerClient = _userWith(
        AppRole.scannerClient,
        defaultPermissionsFor(AppRole.scannerClient).grant(Permission.eaAccess),
      );
      final paths =
          visibleNavDestinationsFor(scannerClient).map((d) => d.path).toSet();
      expect(
        paths.contains('/ea'),
        isTrue,
        reason: 'the deployed read-only EA monitor remains available',
      );
    });

    test('ADMIN sees shipped modules granted by its effective permissions only',
        () {
      final admin =
          _userWith(AppRole.admin, defaultPermissionsFor(AppRole.admin));
      final paths = visibleNavDestinationsFor(admin).map((d) => d.path).toSet();
      expect(paths.contains('/scanner'), isTrue);
      expect(paths.contains('/signals'), isTrue);
      expect(paths.contains('/ea'), isFalse);
      expect(paths.contains('/clients'), isFalse);
      expect(paths.contains('/licences'), isTrue);
    });
  });
}
