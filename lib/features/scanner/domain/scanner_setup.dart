import 'scanner_enums.dart';

/// Backend decimals: Postgres `numeric` is serialised as a string, arrays of
/// it as JSON numbers. Anything else is a contract violation.
double parseWireDecimal(Object? value) => switch (value) {
      num n => n.toDouble(),
      String s => double.parse(s),
      _ => throw FormatException('Expected a decimal', value),
    };

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
    this.market,
    this.brokerSymbol,
    this.strategyProfile,
    this.externalId,
    this.source,
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

  /// Scanner market pack (`FOREX`, `INDICES`, ...) — backend `market_code`.
  final String? market;

  /// Symbol on the reference MT5 feed that produced the setup (e.g. `DE30m`
  /// for canonical `DE40`). Detection metadata; never editable.
  final String? brokerSymbol;

  /// Frozen strategy version that produced the setup (e.g. `CPT-007-v0.2.0`).
  final String? strategyProfile;

  /// The publisher's idempotency key. Set only on machine-published setups,
  /// whose symbol/timeframe/direction the backend treats as immutable.
  final String? externalId;

  /// Origin recorded by the backend (e.g. `CPT_SCANNER:<publisher>`).
  final String? source;

  bool get isMachinePublished => externalId != null;

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
      market: market,
      brokerSymbol: brokerSymbol,
      strategyProfile: strategyProfile,
      externalId: externalId,
      source: source,
    );
  }

  /// Decodes a `public.scanner_setups` row as returned by the CodePhantom
  /// backend (`GET /scanner/setups`, approve/reject/PATCH responses).
  ///
  /// Wire notes: `entry`/`stop_loss` arrive as decimal strings (Postgres
  /// `numeric`, e.g. "2650.120000") and `take_profits` as JSON numbers;
  /// both forms are accepted. Timestamps are UTC ISO-8601. Optional
  /// descriptive fields the scanner does not send decode to
  /// [Bias.unknown]/[TradingSession.unknown]; direction and status never
  /// fall back to a guess.
  factory ScannerSetup.fromBackendJson(Map<String, dynamic> row) {
    return ScannerSetup(
      id: row['id'] as String,
      symbol: row['symbol'] as String,
      timeframe: row['timeframe'] as String,
      direction: SetupDirection.fromWire(row['direction'] as String),
      entry: parseWireDecimal(row['entry']),
      stopLoss: parseWireDecimal(row['stop_loss']),
      takeProfits: (row['take_profits'] as List<dynamic>? ?? const []).map(parseWireDecimal).toList(growable: false),
      weeklyBias: Bias.fromWire(row['weekly_bias'] as String?),
      dailyBias: Bias.fromWire(row['daily_bias'] as String?),
      session: TradingSession.fromWire(row['session'] as String?),
      confluenceScore: (row['confluence_score'] as num?)?.toInt() ?? 0,
      confluenceMaximum: (row['confluence_max'] as num?)?.toInt() ?? 0,
      status: SetupStatus.fromWire(row['status'] as String),
      detectedAt: DateTime.parse(row['detected_at'] as String),
      notes: row['notes'] as String?,
      chartImageUrl: row['chart_image_url'] as String?,
      reviewedAt: row['reviewed_at'] == null ? null : DateTime.parse(row['reviewed_at'] as String),
      reviewedBy: row['reviewed_by'] as String?,
      rejectionReason: row['rejection_reason'] as String?,
      editedBeforeApproval: row['edited_before_approval'] as bool? ?? false,
      market: row['market_code'] as String?,
      brokerSymbol: row['broker_symbol'] as String?,
      strategyProfile: row['strategy_profile'] as String?,
      externalId: row['external_id'] as String?,
      source: row['source'] as String?,
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
      market: json['market'] as String?,
      brokerSymbol: json['brokerSymbol'] as String?,
      strategyProfile: json['strategyProfile'] as String?,
      externalId: json['externalId'] as String?,
      source: json['source'] as String?,
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
        if (market != null) 'market': market,
        if (brokerSymbol != null) 'brokerSymbol': brokerSymbol,
        if (strategyProfile != null) 'strategyProfile': strategyProfile,
        if (externalId != null) 'externalId': externalId,
        if (source != null) 'source': source,
      };
}
