import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/features/ea/presentation/gilgamesh_panel.dart';

void main() {
  testWidgets('Uncertain receipt never claims execution or a loss',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gilgameshProvider.overrideWith(
            (ref) async => {
              'sessions': <dynamic>[],
              'events': [
                {
                  'payload': {
                    'kind': 'RECEIPT',
                    'receipt_status': 'UNCERTAIN',
                  },
                  'observed_at': '2026-10-08',
                  'received_at': '2026-10-08',
                }
              ],
            },
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: GilgameshPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Broker submission unresolved. Do not retry.'),
      findsOneWidget,
    );
    expect(
      find.text('LIVE and FUNDED locked. Order submission disabled.'),
      findsOneWidget,
    );
    expect(find.textContaining('Broker order acknowledged'), findsNothing);
  });
  testWidgets('Refresh is accessible and retries the evidence request',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gilgameshProvider.overrideWith((ref) async {
            calls++;
            return {'sessions': <dynamic>[], 'events': <dynamic>[]};
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: GilgameshPanel())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh broker lifecycle'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('Position state is unknown'), findsOneWidget);
  });
}
