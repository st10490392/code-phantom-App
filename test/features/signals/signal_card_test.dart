import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/features/signals/domain/signal.dart';
import 'package:code_phantom_app/features/signals/domain/signal_enums.dart';
import 'package:code_phantom_app/features/signals/presentation/widgets/signal_card.dart';

void main() {
  testWidgets(
      'cancelled suggestions show update, supported TP2 and no private result',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SignalCard(
                signal: Signal(
      id: 'test',
      symbol: 'EURUSD',
      timeframe: 'M30',
      direction: SetupDirection.buy,
      entry: 1.1,
      stopLoss: 1.09,
      takeProfits: const [1.12, 1.13, 1.14],
      status: SignalStatus.cancelled,
      session: TradingSession.unknown,
      openedAt: DateTime.utc(2026, 10, 8),
      result: 'private strategy diagnostic',
    ),),),),);
    expect(find.text('CPT Market Update'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('TP2'), findsOneWidget);
    expect(find.text('1.14000'), findsNothing);
    expect(find.textContaining('private strategy'), findsNothing);
    expect(find.textContaining('Broker execution is not confirmed'),
        findsOneWidget,);
  });
}
