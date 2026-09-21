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

enum SetupStatus {
  pending,
  approved,
  rejected;

  String get wireValue => switch (this) {
        SetupStatus.pending => 'PENDING',
        SetupStatus.approved => 'APPROVED',
        SetupStatus.rejected => 'REJECTED',
      };

  static SetupStatus fromWire(String v) => switch (v) {
        'APPROVED' => SetupStatus.approved,
        'REJECTED' => SetupStatus.rejected,
        _ => SetupStatus.pending,
      };
}
