import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission.dart';
import 'package:code_phantom_app/core/permissions/permission_set.dart';
import 'package:code_phantom_app/features/auth/domain/auth_user.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/dashboard/presentation/dashboard_screen.dart';

/// Section headings the dashboard renders per module — kept in one place so
/// the test reads as "which of these headings show up", matching how
/// `DashboardScreen` actually gates each section on a permission.
const _scanner = 'Scanner';
const _signals = 'Signals';
const _ea = 'EA';

void main() {
  Future<void> pumpDashboardAs(WidgetTester tester, AuthUser? user) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserProvider.overrideWithValue(user)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    // Mock services resolve in well under a second; a bounded pump avoids
    // pumpAndSettle's indefinite wait, which never completes here because
    // the loading state's CircularProgressIndicator repeats forever.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('OWNER sees every production module summary on the dashboard', (tester) async {
    const owner = AuthUser(
      id: 'u_owner',
      email: 'owner@codephantom.dev',
      displayName: 'Owner',
      role: AppRole.owner,
      permissions: PermissionSet.none,
    );

    await pumpDashboardAs(tester, owner);

    expect(find.text(_scanner), findsOneWidget);
    expect(find.text(_signals), findsOneWidget);
    expect(find.text(_ea), findsOneWidget);
  });

  testWidgets('an EA-only client sees only the EA summary',
      (tester) async {
    const eaClient = AuthUser(
      id: 'u_ea',
      email: 'ea.client@codephantom.dev',
      displayName: 'EA-Only Client',
      role: AppRole.eaClient,
      permissions: PermissionSet({Permission.eaAccess}),
    );

    await pumpDashboardAs(tester, eaClient);

    expect(find.text(_ea), findsOneWidget);
    expect(find.text(_scanner), findsNothing);
    expect(find.text(_signals), findsNothing);
  });

  testWidgets('a scanner-only client sees only the Scanner summary', (tester) async {
    const scannerClient = AuthUser(
      id: 'u_scanner',
      email: 'scanner.client@codephantom.dev',
      displayName: 'Scanner-Only Client',
      role: AppRole.scannerClient,
      permissions: PermissionSet({Permission.scannerAccess}),
    );

    await pumpDashboardAs(tester, scannerClient);

    expect(find.text(_scanner), findsOneWidget);
    expect(find.text(_signals), findsNothing);
    expect(find.text(_ea), findsNothing);
  });

  testWidgets('Notifications always renders regardless of module permissions', (tester) async {
    const scannerClient = AuthUser(
      id: 'u_scanner',
      email: 'scanner.client@codephantom.dev',
      displayName: 'Scanner-Only Client',
      role: AppRole.scannerClient,
      permissions: PermissionSet({Permission.scannerAccess}),
    );

    await pumpDashboardAs(tester, scannerClient);

    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets(
    'a new CLIENT with zero permissions gets the Scanner activation gate',
    (tester) async {
      const newClient = AuthUser(
        id: 'u_client',
        email: 'new.client@codephantom.dev',
        displayName: 'New Client',
        role: AppRole.client,
        permissions: PermissionSet.none,
      );

      await pumpDashboardAs(tester, newClient);

      expect(find.text('Activate CPT Scanner'), findsOneWidget);
      expect(find.text('Activate Scanner'), findsOneWidget);
      expect(find.text('Scanner activation key'), findsOneWidget);
      expect(find.text(_scanner), findsNothing);
      expect(find.text(_signals), findsNothing);
      expect(find.text(_ea), findsNothing);
    },
  );
}
