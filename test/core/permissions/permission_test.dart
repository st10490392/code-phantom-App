import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission.dart';
import 'package:code_phantom_app/core/permissions/permission_set.dart';
import 'package:code_phantom_app/core/permissions/role_defaults.dart';

void main() {
  group('PermissionSet', () {
    test('none grants nothing', () {
      expect(PermissionSet.none.has(Permission.scannerAccess), isFalse);
    });

    test('owner has every permission', () {
      for (final p in Permission.values) {
        expect(PermissionSet.owner.has(p), isTrue);
      }
    });

    test('grant/revoke are independent, non-mutating operations', () {
      const base = PermissionSet.none;
      final withScanner = base.grant(Permission.scannerAccess);

      expect(base.has(Permission.scannerAccess), isFalse, reason: 'original set must be unchanged');
      expect(withScanner.has(Permission.scannerAccess), isTrue);

      final withoutScanner = withScanner.revoke(Permission.scannerAccess);
      expect(withoutScanner.has(Permission.scannerAccess), isFalse);
    });

    test('round-trips through wire format', () {
      const original = PermissionSet({Permission.scannerAccess, Permission.eaAccess});
      final restored = PermissionSet.fromWire(original.toWire());
      expect(restored.granted, equals(original.granted));
    });

    test(
      'two users with the same role can have different effective permissions '
      '(brief\'s User A / User B example)',
      () {
        final userA = defaultPermissionsFor(AppRole.trader)
            .grant(Permission.scannerAccess)
            .grant(Permission.signalsAccess)
            .revoke(Permission.eaAccess);
        final userB = userA.grant(Permission.eaAccess);

        expect(userA.has(Permission.eaAccess), isFalse);
        expect(userB.has(Permission.eaAccess), isTrue);
        expect(userA.has(Permission.scannerAccess), isTrue);
        expect(userB.has(Permission.scannerAccess), isTrue);
      },
    );
  });

  group('role defaults', () {
    test('INTERNAL starts with no permissions — every grant must be explicit', () {
      expect(defaultPermissionsFor(AppRole.internal).granted, isEmpty);
    });

    test('SCANNER_CLIENT defaults to scanner access only', () {
      final perms = defaultPermissionsFor(AppRole.scannerClient);
      expect(perms.has(Permission.scannerAccess), isTrue);
      expect(perms.has(Permission.signalsAccess), isFalse);
      expect(perms.has(Permission.eaAccess), isFalse);
    });

    test('ADMIN does not get systemAdmin-only owner powers beyond its defaults', () {
      final perms = defaultPermissionsFor(AppRole.admin);
      expect(perms.has(Permission.clientAdmin), isTrue);
      expect(perms.has(Permission.licenceAdmin), isTrue);
      expect(perms.has(Permission.eaAccess), isFalse);
    });
  });
}
