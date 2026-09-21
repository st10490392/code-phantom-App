import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/core/permissions/app_role.dart';
import 'package:code_phantom_app/core/permissions/permission.dart';
import 'package:code_phantom_app/core/permissions/permission_set.dart';
import 'package:code_phantom_app/features/auth/domain/auth_user.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';
import 'package:code_phantom_app/features/scanner/domain/scanner_enums.dart';
import 'package:code_phantom_app/features/scanner/domain/scanner_setup.dart';
import 'package:code_phantom_app/features/scanner/presentation/scanner_screen.dart';
import 'package:code_phantom_app/features/scanner/presentation/setup_detail_screen.dart';

const _owner = AuthUser(
  id: 'u_owner',
  email: 'owner@codephantom.dev',
  displayName: 'Owner',
  role: AppRole.owner,
  permissions: PermissionSet.none,
);

const _scannerClient = AuthUser(
  id: 'u_scanner_client',
  email: 'scanner.client@codephantom.dev',
  displayName: 'Scanner Client',
  role: AppRole.scannerClient,
  permissions: PermissionSet({Permission.scannerAccess}),
);

final _pendingFixture = ScannerSetup(
  id: 'fixture_pending',
  symbol: 'EURUSD',
  timeframe: 'M30',
  direction: SetupDirection.buy,
  entry: 1.1000,
  stopLoss: 1.0950,
  takeProfits: const [1.1100],
  weeklyBias: Bias.bullish,
  dailyBias: Bias.bullish,
  session: TradingSession.london,
  confluenceScore: 5,
  confluenceMaximum: 6,
  status: SetupStatus.pending,
  detectedAt: DateTime.now(),
);

Future<void> _settle(WidgetTester tester) async {
  // Bounded pump: a loading spinner's CircularProgressIndicator repeats
  // forever and would never let pumpAndSettle finish.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  Future<void> pumpScannerScreen(WidgetTester tester, AuthUser user) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserProvider.overrideWithValue(user)],
        child: const MaterialApp(home: ScannerScreen()),
      ),
    );
    await _settle(tester);
  }

  testWidgets('scanner tabs filter correctly: a reviewer sees all four tabs', (tester) async {
    await pumpScannerScreen(tester, _owner);

    expect(find.widgetWithText(Tab, 'Pending'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Approved'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Rejected'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'History'), findsOneWidget);
  });

  testWidgets('scanner tabs filter correctly: a non-reviewer only ever sees Approved', (tester) async {
    await pumpScannerScreen(tester, _scannerClient);

    expect(find.widgetWithText(Tab, 'Pending'), findsNothing);
    expect(find.widgetWithText(Tab, 'Rejected'), findsNothing);
    expect(find.widgetWithText(Tab, 'History'), findsNothing);
    expect(find.widgetWithText(Tab, 'Approved'), findsOneWidget);
  });

  Future<void> pumpDetailBody(WidgetTester tester, AuthUser user) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserProvider.overrideWithValue(user)],
        child: MaterialApp(
          home: Scaffold(body: SetupDetailBody(setup: _pendingFixture)),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('review actions are visible to an authorized reviewer (OWNER)', (tester) async {
    await pumpDetailBody(tester, _owner);

    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('review actions are hidden from a non-review user (SCANNER_CLIENT)', (tester) async {
    await pumpDetailBody(tester, _scannerClient);

    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(find.text('Edit'), findsNothing);
  });
}
