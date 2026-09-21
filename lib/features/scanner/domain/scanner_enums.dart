enum SetupDirection {
  buy,
  sell;

  String get wireValue => this == SetupDirection.buy ? 'BUY' : 'SELL';
  static SetupDirection fromWire(String v) => v == 'BUY' ? SetupDirection.buy : SetupDirection.sell;
}

enum Bias {
  bullish,
  bearish,
  neutral;

  String get wireValue => switch (this) {
        Bias.bullish => 'BULLISH',
        Bias.bearish => 'BEARISH',
        Bias.neutral => 'NEUTRAL',
      };

  static Bias fromWire(String v) => switch (v) {
        'BULLISH' => Bias.bullish,
        'BEARISH' => Bias.bearish,
        _ => Bias.neutral,
      };
}

enum TradingSession {
  asia,
  london,
  newYork,
  overlap;

  String get wireValue => switch (this) {
        TradingSession.asia => 'ASIA',
        TradingSession.london => 'LONDON',
        TradingSession.newYork => 'NEW_YORK',
        TradingSession.overlap => 'OVERLAP',
      };

  static TradingSession fromWire(String v) => switch (v) {
        'ASIA' => TradingSession.asia,
        'LONDON' => TradingSession.london,
        'NEW_YORK' => TradingSession.newYork,
        _ => TradingSession.overlap,
      };
}

/// A setup's OWN lifecycle: it is detected, then reviewed to a terminal
/// outcome. `PUBLISHED`/`ACTIVE`/closed-with-a-result belong to the
/// [Signal] created from an approved setup (see
/// `features/signals/domain/signal_mapper.dart`) — duplicating that
/// lifecycle here would give two disagreeing sources of truth for the same
/// trade idea once it's live. `reviewedAt`/`reviewedBy`/`rejectionReason`
/// on [ScannerSetup] close the loop on what happened to a given detection.
enum SetupStatus {
  pending,
  approved,
  rejected,
  cancelled,
  expired;

  String get wireValue => switch (this) {
        SetupStatus.pending => 'PENDING',
        SetupStatus.approved => 'APPROVED',
        SetupStatus.rejected => 'REJECTED',
        SetupStatus.cancelled => 'CANCELLED',
        SetupStatus.expired => 'EXPIRED',
      };

  bool get isTerminal => this != SetupStatus.pending;

  static SetupStatus fromWire(String v) => switch (v) {
        'APPROVED' => SetupStatus.approved,
        'REJECTED' => SetupStatus.rejected,
        'CANCELLED' => SetupStatus.cancelled,
        'EXPIRED' => SetupStatus.expired,
        _ => SetupStatus.pending,
      };
}

/// Valid forward transitions for a setup's review lifecycle — mirrors
/// `signal_enums.dart`'s `signalStatusTransitions` pattern. Every terminal
/// status is a dead end: a setup is reviewed exactly once.
const Map<SetupStatus, List<SetupStatus>> setupStatusTransitions = {
  SetupStatus.pending: [
    SetupStatus.approved,
    SetupStatus.rejected,
    SetupStatus.cancelled,
    SetupStatus.expired,
  ],
  SetupStatus.approved: [],
  SetupStatus.rejected: [],
  SetupStatus.cancelled: [],
  SetupStatus.expired: [],
};

bool isValidSetupTransition(SetupStatus from, SetupStatus to) {
  return setupStatusTransitions[from]?.contains(to) ?? false;
}
