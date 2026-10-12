class SignalPerformanceSummary {
  const SignalPerformanceSummary({
    required this.totalSignals,
    required this.wins,
    required this.losses,
    required this.winRatePercent,
    required this.averageRMultiple,
    this.rObservationCount = 0,
  });

  final int rObservationCount;
  final int totalSignals;
  final int wins;
  final int losses;
  final double winRatePercent;
  final double averageRMultiple;
}
