import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/features/signals/presentation/signal_detail_screen.dart';
import 'package:code_phantom_app/features/auth/presentation/auth_providers.dart';

const signalId = '87654321-4321-4321-4321-210987654321';

void main() {
  test('signal detail requires a restored authenticated user before any read', () async {
    final container = ProviderContainer(overrides: [currentUserProvider.overrideWithValue(null)]);
    addTearDown(container.dispose);
    await expectLater(container.read(entitledSignalProvider(signalId).future), throwsStateError);
  });

  testWidgets('revoked/missing signal exposes no provider or strategy diagnostics', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [entitledSignalProvider(signalId).overrideWith((ref) async => throw StateError('strategy_hash=private; account=secret'))],
      child: const MaterialApp(home: SignalDetailScreen(signalId: signalId)),
    ),);
    await tester.pumpAndSettle();
    expect(find.text('Signal unavailable or access has ended.'), findsOneWidget);
    expect(find.textContaining('strategy_hash'), findsNothing);
    expect(find.textContaining('secret'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
}
