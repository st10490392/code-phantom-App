import '../../scanner/domain/scanner_setup.dart';
import '../domain/signal.dart';
import '../domain/signal_enums.dart';
import '../domain/signal_performance_summary.dart';

abstract class SignalService {
  Stream<List<Signal>> watchSignals({SignalStatus? status});

  /// Throws [StateError] if `status` is not a valid transition from the
  /// signal's current status — see `signal_enums.dart`'s transition table.
  Future<Signal> updateStatus(String signalId, SignalStatus status);

  Future<SignalPerformanceSummary> performanceSummary();

  /// Creates and stores a new [Signal] from an approved [ScannerSetup] —
  /// see `signal_mapper.dart` for the field mapping. This is how the
  /// Scanner Approval workflow hands a reviewed setup to the Signals
  /// module without the UI ever touching either model's internals.
  Future<Signal> createFromSetup(ScannerSetup setup);
}
