import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission.dart';
import 'package:code_phantom_app/core/permissions/permission_set.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/auth/domain/auth_user.dart';
import 'package:code_phantom_app/core/routing/nav_destination.dart';

void main() {
  group('Integrations navigation visibility', () {
    test('OWNER sees the Integrations navigation item', () {
      const owner = AuthUser(
        id: 'owner1',
        email: 'owner@codephantom.dev',
        displayName: 'Owner',
        role: AppRole.owner,
        permissions: PermissionSet.owner,
      );

      final visible = visibleNavDestinationsFor(owner);
      final hasIntegrations = visible.any((d) => d.path == '/integrations');

      expect(hasIntegrations, isTrue);
    });

    test('User without integrationsManage does not see Integrations nav item', () {
      const admin = AuthUser(
        id: 'admin1',
        email: 'admin@codephantom.dev',
        displayName: 'Admin',
        role: AppRole.admin,
        permissions: PermissionSet({
          Permission.scannerAccess,
          Permission.signalsAccess,
        }), // missing integrationsManage
      );

      final visible = visibleNavDestinationsFor(admin);
      final hasIntegrations = visible.any((d) => d.path == '/integrations');

      expect(hasIntegrations, isFalse);
    });

    test('User with integrationsManage permission sees the Integrations nav item',
        () {
      const user = AuthUser(
        id: 'user1',
        email: 'user@codephantom.dev',
        displayName: 'User',
        role: AppRole.internal,
        permissions: PermissionSet({Permission.integrationsManage}),
      );

      final visible = visibleNavDestinationsFor(user);
      final hasIntegrations = visible.any((d) => d.path == '/integrations');

      expect(hasIntegrations, isTrue);
    });

    test('Signed out user does not see Integrations nav item', () {
      final visible = visibleNavDestinationsFor(null);
      final hasIntegrations = visible.any((d) => d.path == '/integrations');

      expect(hasIntegrations, isFalse);
    });
  });
}