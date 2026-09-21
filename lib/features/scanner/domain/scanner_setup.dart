import 'scanner_enums.dart';

class ScannerSetup {
  const ScannerSetup({
    required this.id,
    required this.symbol,
    required this.timeframe,
    required this.direction,
    required this.entry,
    required this.stopLoss,
    required this.takeProfits,
    required this.weeklyBias,
    required this.dailyBias,
    required this.session,
    required this.confluenceScore,
    required this.confluenceMaximum,
    required this.status,
    required this.detectedAt,
    this.notes,
    this.chartImageUrl,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.editedBeforeApproval = false,
  });

  final String id;
  final String symbol;
  final String timeframe;
  final SetupDirection direction;
  final double entry;
  final double stopLoss;

  /// [TP1, TP2, TP3] — may have fewer than 3 entries.
  final List<double> takeProfits;
  final Bias weeklyBias;
  final Bias dailyBias;
  final TradingSession session;
  final int confluenceScore;
  final int confluenceMaximum;
  final SetupStatus status;

  /// When the (mock) scanner engine first detected this setup. Immutable
  /// after construction — `copyWith` deliberately has no parameter for it,
  /// so an edit before approval can never alter the original detection time.
  final DateTime detectedAt;
  final String? notes;
  final String? chartImageUrl;

  /// When an OWNER/ADMIN reviewer actioned this setup (approve or reject).
  final DateTime? reviewedAt;

  /// Display name of the reviewer who actioned this setup.
  final String? reviewedBy;

  /// Set only when [status] is [SetupStatus.rejected] — one of
  /// `scannerRejectionReasons` or free text if "Other" was chosen.
  final String? rejectionReason;

  /// True once a reviewer has changed a material trade field (entry, stop
  /// loss, take profits, direction, or timeframe) prior to approval. Set by
  /// `MockScannerService.update()`, never by the UI directly, so it can't
  /// be forgotten or faked by a widget.
  final bool editedBeforeApproval;

  double? get tp1 => takeProfits.isNotEmpty ? takeProfits[0] : null;
  double? get tp2 => takeProfits.length > 1 ? takeProfits[1] : null;
  double? get tp3 => takeProfits.length > 2 ? takeProfits[2] : null;

  ScannerSetup copyWith({
    String? timeframe,
    SetupDirection? direction,
    double? entry,
    double? stopLoss,
    List<double>? takeProfits,
    SetupStatus? status,
    String? notes,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? rejectionReason,
    bool? editedBeforeApproval,
  }) {
    return ScannerSetup(
      id: id,
      symbol: symbol,
      timeframe: timeframe ?? this.timeframe,
      direction: direction ?? this.direction,
      entry: entry ?? this.entry,
      stopLoss: stopLoss ?? this.stopLoss,
      takeProfits: takeProfits ?? this.takeProfits,
      weeklyBias: weeklyBias,
      dailyBias: dailyBias,
      session: session,
      confluenceScore: confluenceScore,
      confluenceMaximum: confluenceMaximum,
      status: status ?? this.status,
      detectedAt: detectedAt,
      notes: notes ?? this.notes,
      chartImageUrl: chartImageUrl,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      editedBeforeApproval: editedBeforeApproval ?? this.editedBeforeApproval,
    );
  }

  factory ScannerSetup.fromJson(Map<String, dynamic> json) {
    return ScannerSetup(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      timeframe: json['timeframe'] as String,
      direction: SetupDirection.fromWire(json['direction'] as String),
      entry: (json['entry'] as num).toDouble(),
      stopLoss: (json['stopLoss'] as num).toDouble(),
      takeProfits: (json['takeProfits'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      weeklyBias: Bias.fromWire(json['weeklyBias'] as String),
      dailyBias: Bias.fromWire(json['dailyBias'] as String),
      session: TradingSession.fromWire(json['session'] as String),
      confluenceScore: json['confluenceScore'] as int,
      confluenceMaximum: json['confluenceMaximum'] as int,
      status: SetupStatus.fromWire(json['status'] as String),
      detectedAt: DateTime.parse(json['detectedAt'] as String),
      notes: json['notes'] as String?,
      chartImageUrl: json['chartImageUrl'] as String?,
      reviewedAt: json['reviewedAt'] != null ? DateTime.parse(json['reviewedAt'] as String) : null,
      reviewedBy: json['reviewedBy'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      editedBeforeApproval: json['editedBeforeApproval'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'timeframe': timeframe,
        'direction': direction.wireValue,
        'entry': entry,
        'stopLoss': stopLoss,
        'takeProfits': takeProfits,
        'weeklyBias': weeklyBias.wireValue,
        'dailyBias': dailyBias.wireValue,
        'session': session.wireValue,
        'confluenceScore': confluenceScore,
        'confluenceMaximum': confluenceMaximum,
        'status': status.wireValue,
        'detectedAt': detectedAt.toIso8601String(),
        if (notes != null) 'notes': notes,
        if (chartImageUrl != null) 'chartImageUrl': chartImageUrl,
        if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        'editedBeforeApproval': editedBeforeApproval,
      };
}
