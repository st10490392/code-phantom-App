import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/features/signals/data/mock_signal_service.dart';
import 'package:code_phantom_app/features/signals/domain/signal_enums.dart';

void main() {
  group('isValidSignalTransition', () {
    test('PENDING can move to APPROVED or CANCELLED', () {
      expect(isValidSignalTransition(SignalStatus.pending, SignalStatus.approved), isTrue);
      expect(isValidSignalTransition(SignalStatus.pending, SignalStatus.cancelled), isTrue);
    });

    test('PENDING cannot jump straight to ACTIVE', () {
      expect(isValidSignalTransition(SignalStatus.pending, SignalStatus.active), isFalse);
    });

    test('terminal statuses have no valid outgoing transitions', () {
      for (final terminal in [SignalStatus.stopped, SignalStatus.cancelled, SignalStatus.closed]) {
        for (final target in SignalStatus.values) {
          expect(isValidSignalTransition(terminal, target), isFalse);
        }
      }
    });

    test('ACTIVE can reach any TP or STOPPED/CLOSED', () {
      expect(isValidSignalTransition(SignalStatus.active, SignalStatus.tp1Hit), isTrue);
      expect(isValidSignalTransition(SignalStatus.active, SignalStatus.stopped), isTrue);
      expect(isValidSignalTransition(SignalStatus.active, SignalStatus.closed), isTrue);
    });
  });

  group('MockSignalService.updateStatus', () {
    late MockSignalService service;
    setUp(() => service = MockSignalService());

    test('rejects an invalid transition', () async {
      final signals = await service.watchSignals().first;
      final closedSignal = signals.firstWhere((s) => s.status.isClosed);

      expect(
        () => service.updateStatus(closedSignal.id, SignalStatus.active),
        throwsA(isA<StateError>()),
      );
    });

    test('applies a valid transition and stamps closedAt when terminal', () async {
      final signals = await service.watchSignals().first;
      final activeLike = signals.firstWhere((s) => s.status == SignalStatus.tp1Hit);

      final updated = await service.updateStatus(activeLike.id, SignalStatus.closed);

      expect(updated.status, SignalStatus.closed);
      expect(updated.closedAt, isNotNull);
    });
  });
}
