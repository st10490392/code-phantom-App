import '../../scanner/domain/scanner_enums.dart';

export '../../scanner/domain/scanner_enums.dart' show SetupDirection, TradingSession;

enum SignalStatus {
  pending,
  approved,
  published,
  active,
  tp1Hit,
  tp2Hit,
  tp3Hit,
  stopped,
  cancelled,
  closed;

  String get wireValue => switch (this) {
        SignalStatus.pending => 'PENDING',
        SignalStatus.approved => 'APPROVED',
        SignalStatus.published => 'PUBLISHED',
        SignalStatus.active => 'ACTIVE',
        SignalStatus.tp1Hit => 'TP1_HIT',
        SignalStatus.tp2Hit => 'TP2_HIT',
        SignalStatus.tp3Hit => 'TP3_HIT',
        SignalStatus.stopped => 'STOPPED',
        SignalStatus.cancelled => 'CANCELLED',
        SignalStatus.closed => 'CLOSED',
      };

  bool get isClosed => this == SignalStatus.stopped ||
      this == SignalStatus.cancelled ||
      this == SignalStatus.closed;

  bool get isActive => !isClosed && this != SignalStatus.pending;

  static SignalStatus fromWire(String v) => SignalStatus.values.firstWhere(
        (s) => s.wireValue == v,
        orElse: () => SignalStatus.pending,
      );
}

/// Valid forward transitions for a signal's lifecycle — used by
/// `SignalService` and tested in `test/features/signals/`.
const Map<SignalStatus, List<SignalStatus>> signalStatusTransitions = {
  SignalStatus.pending: [SignalStatus.approved, SignalStatus.cancelled],
  SignalStatus.approved: [SignalStatus.published, SignalStatus.cancelled],
  SignalStatus.published: [SignalStatus.active, SignalStatus.cancelled],
  SignalStatus.active: [
    SignalStatus.tp1Hit,
    SignalStatus.tp2Hit,
    SignalStatus.tp3Hit,
    SignalStatus.stopped,
    SignalStatus.closed,
  ],
  SignalStatus.tp1Hit: [SignalStatus.tp2Hit, SignalStatus.tp3Hit, SignalStatus.closed, SignalStatus.stopped],
  SignalStatus.tp2Hit: [SignalStatus.tp3Hit, SignalStatus.closed, SignalStatus.stopped],
  SignalStatus.tp3Hit: [SignalStatus.closed],
  SignalStatus.stopped: [],
  SignalStatus.cancelled: [],
  SignalStatus.closed: [],
};

bool isValidSignalTransition(SignalStatus from, SignalStatus to) {
  return signalStatusTransitions[from]?.contains(to) ?? false;
}
