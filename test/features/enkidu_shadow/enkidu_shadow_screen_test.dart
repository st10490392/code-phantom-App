import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/features/enkidu_shadow/enkidu_shadow_screen.dart';

void main() {
  testWidgets('owner SHADOW card states provenance and nonexecution', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      enkiduShadowObservationsProvider.overrideWith((ref) async => [
        <String,dynamic>{
          'symbol':'EURUSD','direction':'BUY','state':'THEORETICAL_TP',
          'observed_at':'2026-10-08T14:00:30Z','cutoff_at':'2026-10-08T14:00:00Z',
          'expires_at':'2026-10-08T14:02:00Z','entry':100,'stop_loss':90,'take_profit':110,
          'run_id':'fixture-run','source_sha256':List.filled(64,'a').join(),
          'gate_policy_sha256':List.filled(64,'b').join(),
          'gate_receipt_sha256':List.filled(64,'c').join(),
          'strategy_sha256':List.filled(64,'d').join(),
        },
      ]),
    ], child: const MaterialApp(home: EnkiduShadowScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('THEORETICAL_TP'), findsOneWidget);
    expect(find.textContaining('no broker order or realized profit'), findsOneWidget);
    expect(find.textContaining('Gate receipt:'), findsOneWidget);
  });
}
