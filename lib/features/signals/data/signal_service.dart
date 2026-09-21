import '../domain/signal.dart';
import '../domain/signal_enums.dart';
import '../domain/signal_performance_summary.dart';

abstract class SignalService {
  Stream<List<Signal>> watchSignals({SignalStatus? status});

  /// Throws [StateError] if `status` is not a valid transition from the
  /// signal's current status — see `signal_enums.dart`'s transition table.
  Future<Signal> updateStatus(String signalId, SignalStatus status);

  Future<SignalPerformanceSummary> performanceSummary();
}
