enum SetupDirection {
  buy,
  sell;

  String get wireValue => this == SetupDirection.buy ? 'BUY' : 'SELL';

  /// A trade direction is never guessed: anything other than BUY/SELL is a
  /// contract violation and fails loudly instead of rendering as a SELL.
  static SetupDirection fromWire(String v) => switch (v) {
        'BUY' => SetupDirection.buy,
        'SELL' => SetupDirection.sell,
        _ => throw FormatException('Unknown setup direction', v),
      };
}

/// [unknown] means the source did not report a bias (the CPT Scanner does
/// not publish one). It is shown as absent, never as a fabricated NEUTRAL.
enum Bias {
  bullish,
  bearish,
  neutral,
  unknown;

  String get wireValue => switch (this) {
        Bias.bullish => 'BULLISH',
        Bias.bearish => 'BEARISH',
        Bias.neutral => 'NEUTRAL',
        Bias.unknown => 'UNKNOWN',
      };

  bool get isKnown => this != Bias.unknown;

  static Bias fromWire(String? v) => switch (v?.toUpperCase()) {
        'BULLISH' => Bias.bullish,
        'BEARISH' => Bias.bearish,
        'NEUTRAL' => Bias.neutral,
        _ => Bias.unknown,
      };
}

/// [unknown] means no session was reported (backend `session` is nullable).
enum TradingSession {
  asia,
  london,
  newYork,
  overlap,
  unknown;

  String get wireValue => switch (this) {
        TradingSession.asia => 'ASIA',
        TradingSession.london => 'LONDON',
        TradingSession.newYork => 'NEW_YORK',
        TradingSession.overlap => 'OVERLAP',
        TradingSession.unknown => 'UNKNOWN',
      };

  bool get isKnown => this != TradingSession.unknown;

  static TradingSession fromWire(String? v) => switch (v?.toUpperCase()) {
        'ASIA' => TradingSession.asia,
        'LONDON' => TradingSession.london,
        'NEW_YORK' => TradingSession.newYork,
        'OVERLAP' => TradingSession.overlap,
        _ => TradingSession.unknown,
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

  /// Unknown statuses fail loudly: defaulting to PENDING would put
  /// Approve/Reject controls on a setup whose real state is unknown.
  static SetupStatus fromWire(String v) => switch (v) {
        'PENDING' => SetupStatus.pending,
        'APPROVED' => SetupStatus.approved,
        'REJECTED' => SetupStatus.rejected,
        'CANCELLED' => SetupStatus.cancelled,
        'EXPIRED' => SetupStatus.expired,
        _ => throw FormatException('Unknown setup status', v),
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
