import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission_set.dart';
import 'package:code_phantom_app/features/auth/domain/auth_user.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/scanner/domain/scanner_setup.dart';
import 'package:code_phantom_app/features/scanner/presentation/edit_setup_sheet.dart';
import 'package:code_phantom_app/features/scanner/presentation/setup_detail_screen.dart';
import 'api_scanner_service_test.dart' show scannerRow;

const _owner = AuthUser(
  id: 'u_owner',
  email: 'owner@codephantom.dev',
  displayName: 'Owner',
  role: AppRole.owner,
  permissions: PermissionSet.none,
);

void main() {
  final setup = ScannerSetup.fromBackendJson(scannerRow());

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserProvider.overrideWithValue(_owner)],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump();
  }

  testWidgets('a real PENDING scanner setup shows everything a reviewer needs', (tester) async {
    await pump(tester, SetupDetailBody(setup: setup));

    expect(find.text('DE40 · M30'), findsOneWidget);
    expect(find.text('BUY'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.text('INDICES'), findsOneWidget);
    expect(find.text('DE30m'), findsOneWidget);
    expect(find.text('19250.50000'), findsOneWidget);
    expect(find.text('19210.00000'), findsOneWidget);
    expect(find.text('19331.50000'), findsOneWidget);
    expect(find.textContaining('2026-09-26 10:00 UTC'), findsOneWidget);
    expect(find.text('CPT-007-v0.2.0'), findsOneWidget);
    expect(find.text('DE40-3422f253bcbbf392bec1'), findsOneWidget);
    // Fields the scanner does not report are absent, not shown as NEUTRAL/0.
    expect(find.text('Weekly bias'), findsNothing);
    expect(find.text('Session'), findsNothing);
    expect(find.text('Confluence'), findsNothing);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('customer detail omits strategy versions and hashes even from an old backend response', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(null)],
      child: MaterialApp(home: Scaffold(body: SetupDetailBody(setup: setup))),
    ));
    await tester.pump();
    expect(find.text('DE40 · M30'), findsOneWidget);
    expect(find.text('19250.50000'), findsOneWidget);
    expect(find.text('CPT-007-v0.2.0'), findsNothing);
    expect(find.textContaining('strategy_hash'), findsNothing);
    expect(find.text('DE40-3422f253bcbbf392bec1'), findsNothing);
  });

  testWidgets('editing a scanner-published setup cannot change its direction or timeframe', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showEditSetupSheet(context, setup),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('detected by the scanner, not editable'), findsOneWidget);
    expect(find.text('SELL'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Timeframe'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Stop loss'), findsOneWidget);
  });
}

