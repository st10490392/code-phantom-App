import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission.dart';
import 'package:code_phantom_app/core/permissions/permission_gate.dart';
import 'package:code_phantom_app/core/permissions/permission_set.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/auth/domain/auth_user.dart';

void main() {
  const marker = Key('gated_child');

  Widget buildApp(AuthUser? user) {
    return ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(user),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: PermissionGate(
            permission: Permission.eaControl,
            child: SizedBox(key: marker),
          ),
        ),
      ),
    );
  }

  testWidgets('hides the child when the user lacks the permission', (tester) async {
    const user = AuthUser(
      id: 'u1',
      email: 'trader@codephantom.dev',
      displayName: 'Trader',
      role: AppRole.trader,
      permissions: PermissionSet({Permission.scannerAccess}),
    );

    await tester.pumpWidget(buildApp(user));

    expect(find.byKey(marker), findsNothing);
  });

  testWidgets('shows the child when the user has the permission', (tester) async {
    const user = AuthUser(
      id: 'u2',
      email: 'admin@codephantom.dev',
      displayName: 'Admin',
      role: AppRole.admin,
      permissions: PermissionSet({Permission.eaControl}),
    );

    await tester.pumpWidget(buildApp(user));

    expect(find.byKey(marker), findsOneWidget);
  });

  testWidgets('OWNER always sees the gated child regardless of stored grants', (tester) async {
    const owner = AuthUser(
      id: 'u3',
      email: 'owner@codephantom.dev',
      displayName: 'Owner',
      role: AppRole.owner,
      permissions: PermissionSet.none, // deliberately empty — isOwner short-circuits
    );

    await tester.pumpWidget(buildApp(owner));

    expect(find.byKey(marker), findsOneWidget);
  });

  testWidgets('hides the child when signed out', (tester) async {
    await tester.pumpWidget(buildApp(null));

    expect(find.byKey(marker), findsNothing);
  });
}
