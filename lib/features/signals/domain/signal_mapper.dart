import '../../scanner/domain/scanner_setup.dart';
import 'signal.dart';
import 'signal_enums.dart';

/// Converts an approved [ScannerSetup] into a brand-new [Signal].
///
/// `ScannerSetup` and `Signal` are intentionally separate domain objects —
/// a setup is the scanner-detected trade idea and everything about how it
/// was reviewed (`reviewedAt`/`reviewedBy`/`rejectionReason`/
/// `editedBeforeApproval`); a signal is the thing the Signals module
/// actually tracks through its own PENDING → APPROVED → PUBLISHED →
/// ACTIVE → ... lifecycle and (later) publishes externally. This mapper is
/// the only place that translates one into the other, so the two models
/// never need to be merged.
///
/// The new signal always starts at [SignalStatus.pending] — approving a
/// scanner setup hands the trade idea to the Signals module, it does not
/// itself publish or activate it.
Signal signalFromApprovedSetup(ScannerSetup setup) {
  return Signal(
    id: 'signal_${setup.id}',
    setupId: setup.id,
    symbol: setup.symbol,
    direction: setup.direction,
    entry: setup.entry,
    stopLoss: setup.stopLoss,
    takeProfits: setup.takeProfits,
    status: SignalStatus.pending,
    session: setup.session,
    openedAt: DateTime.now(),
  );
}
