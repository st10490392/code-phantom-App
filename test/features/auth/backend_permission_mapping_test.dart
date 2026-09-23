import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission.dart';
import 'package:code_phantom_app/core/permissions/permission_set.dart';
import 'package:code_phantom_app/core/routing/nav_destination.dart';
import 'package:code_phantom_app/features/auth/data/backend_permission_mapping.dart';

const _ownerPermissionCodes = [
  'scanner.view', 'scanner.review', 'scanner.ingest',
  'signals.view', 'signals.manage', 'signals.publish',
  'ea.view', 'ea.control',
  'clients.view', 'clients.manage',
  'licences.view', 'licences.manage',
  'notifications.view', 'notifications.manage',
  'admin.system',
];

void main() {
  group('permissionSetFromBackendCodes', () {
    test('the real 15 OWNER backend permissions map onto every app Permission', () {
      final set = permissionSetFromBackendCodes(_ownerPermissionCodes);
      for (final p in Permission.values) {
        expect(set.has(p), isTrue, reason: '$p should be granted from the OWNER permission list');
      }
      expect(set.granted, PermissionSet.owner.granted);
    });

    test('a restricted client only gets what its codes map to', () {
      final set = permissionSetFromBackendCodes(const ['scanner.view', 'notifications.view']);
      expect(set.has(Permission.scannerAccess), isTrue);
      expect(set.has(Permission.scannerReview), isFalse);
      expect(set.has(Permission.signalsAccess), isFalse);
      expect(set.has(Permission.clientAdmin), isFalse);
    });

    test('an unrecognized backend code is dropped, not thrown', () {
      final set = permissionSetFromBackendCodes(const ['scanner.view', 'some.future.permission']);
      expect(set.has(Permission.scannerAccess), isTrue);
      expect(set.granted.length, 1);
    });

    test('view and manage variants both grant the single app-level admin gate', () {
      expect(permissionSetFromBackendCodes(const ['clients.view']).has(Permission.clientAdmin), isTrue);
      expect(permissionSetFromBackendCodes(const ['clients.manage']).has(Permission.clientAdmin), isTrue);
      expect(permissionSetFromBackendCodes(const ['licences.view']).has(Permission.licenceAdmin), isTrue);
      expect(permissionSetFromBackendCodes(const ['licences.manage']).has(Permission.licenceAdmin), isTrue);
    });
  });

  group('primaryRoleFromBackendCodes', () {
    test('a single role maps directly', () {
      expect(primaryRoleFromBackendCodes(const ['SCANNER_CLIENT']), AppRole.scannerClient);
    });

    test('multiple roles resolve to the highest-privilege one', () {
      expect(primaryRoleFromBackendCodes(const ['TRADER', 'OWNER']), AppRole.owner);
      expect(primaryRoleFromBackendCodes(const ['SCANNER_CLIENT', 'ADMIN']), AppRole.admin);
    });

    test('an empty or unrecognized role list falls back to INTERNAL', () {
      expect(primaryRoleFromBackendCodes(const []), AppRole.internal);
    });
  });

  group('authUserFromApiProfile', () {
    test('maps id/email/display_name/status/protected/roles/permissions', () {
      final user = authUserFromApiProfile({
        'profile': {
          'id': 'u1',
          'email': 'owner@codephantom.dev',
          'display_name': 'Ripfumelo',
          'status': 'ACTIVE',
          'protected': true,
        },
        'roles': const ['OWNER'],
        'permissions': _ownerPermissionCodes,
      });

      expect(user.id, 'u1');
      expect(user.email, 'owner@codephantom.dev');
      expect(user.displayName, 'Ripfumelo');
      expect(user.status, 'ACTIVE');
      expect(user.protected, isTrue);
      expect(user.role, AppRole.owner);
      expect(user.isOwner, isTrue);
    });

    test('falls back to email when display_name is absent', () {
      final user = authUserFromApiProfile({
        'profile': {'id': 'u2', 'email': 'x@y.com', 'status': 'ACTIVE', 'protected': false},
        'roles': const ['INTERNAL'],
        'permissions': const <String>[],
      });
      expect(user.displayName, 'x@y.com');
    });
  });

  group('navigation built from real server-style permission responses', () {
    test('OWNER navigation shows every module from the real 15-permission response', () {
      final owner = authUserFromApiProfile({
        'profile': {'id': 'u1', 'email': 'owner@codephantom.dev', 'status': 'ACTIVE', 'protected': true},
        'roles': const ['OWNER'],
        'permissions': _ownerPermissionCodes,
      });

      final visible = visibleNavDestinationsFor(owner).map((d) => d.path).toSet();
      expect(visible, primaryNavDestinations.map((d) => d.path).toSet());
    });

    test('a restricted client only sees the modules its backend permissions grant', () {
      final client = authUserFromApiProfile({
        'profile': {'id': 'u3', 'email': 'scanner.client@codephantom.dev', 'status': 'ACTIVE', 'protected': false},
        'roles': const ['SCANNER_CLIENT'],
        'permissions': const ['scanner.view', 'notifications.view'],
      });

      final visible = visibleNavDestinationsFor(client).map((d) => d.path).toSet();
      expect(visible, {'/dashboard', '/scanner', '/notifications', '/settings'});
      expect(visible.contains('/clients'), isFalse);
      expect(visible.contains('/licences'), isFalse);
      expect(visible.contains('/ea'), isFalse);
    });
  });
}
