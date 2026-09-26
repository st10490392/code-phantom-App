import '../../../core/network/api_client.dart';
import '../domain/scanner_enums.dart';
import '../domain/scanner_setup.dart';
import 'scanner_service.dart';

/// Read-only view of the backend scanner queue until strategy validation.
class ApiScannerService implements ScannerService {
  ApiScannerService(this._client, {this.actionsEnabled = false});
  final ApiClient _client;
  final bool actionsEnabled;

  void _requireActions() {
    if (!actionsEnabled) throw StateError('Scanner review awaits strategy validation.');
  }

  Future<List<ScannerSetup>> _list(SetupStatus? status) async {
    final response = await _client.get('/scanner/setups', query: {
      'limit': 200,
      if (status == SetupStatus.pending ||
          status == SetupStatus.approved ||
          status == SetupStatus.rejected)
        'status': status!.wireValue,
    },);
    final rows = response['data'] as List<dynamic>;
    final setups = rows.map((row) => _decode(row as Map<String, dynamic>)).toList();
    return status == null ? setups : setups.where((s) => s.status == status).toList();
  }

  @override
  Stream<List<ScannerSetup>> watchSetups({SetupStatus? status}) async* {
    yield await _list(status);
    yield* Stream.periodic(const Duration(seconds: 30))
        .asyncMap((_) => _list(status));
  }

  @override
  Future<ScannerSetup?> getSetupById(String id) async {
    final response = await _client.get('/scanner/setups/${Uri.encodeComponent(id)}');
    return _decode(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<ScannerSetup> approve(String setupId, {String? note, String? reviewedBy}) async {
    _requireActions();
    final response = await _client.post(
      '/scanner/setups/${Uri.encodeComponent(setupId)}/approve',
    );
    // Approval and signal creation are one backend transaction.
    return _decode((response['data'] as Map<String, dynamic>)['setup'] as Map<String, dynamic>);
  }

  @override
  Future<ScannerSetup> reject(String setupId, {required String reason, String? reviewedBy}) async {
    _requireActions();
    final response = await _client.post(
      '/scanner/setups/${Uri.encodeComponent(setupId)}/reject',
      body: {'rejection_reason': reason},
    );
    return _decode(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<ScannerSetup> update(ScannerSetup setup) async {
    _requireActions();
    final response = await _client.patch(
      '/scanner/setups/${Uri.encodeComponent(setup.id)}',
      body: {
        'symbol': setup.symbol,
        'timeframe': setup.timeframe,
        'direction': setup.direction.wireValue,
        'entry': setup.entry,
        'stop_loss': setup.stopLoss,
        'take_profits': setup.takeProfits,
        'weekly_bias': setup.weeklyBias.wireValue,
        'daily_bias': setup.dailyBias.wireValue,
        'session': setup.session.wireValue,
        'notes': setup.notes,
      },
    );
    return _decode(response['data'] as Map<String, dynamic>);
  }

  double _number(Object? value) => value is num ? value.toDouble() : double.parse(value as String);

  ScannerSetup _decode(Map<String, dynamic> row) => ScannerSetup(
        id: row['id'] as String,
        symbol: row['symbol'] as String,
        timeframe: row['timeframe'] as String,
        direction: SetupDirection.fromWire(row['direction'] as String),
        entry: _number(row['entry']),
        stopLoss: _number(row['stop_loss']),
        takeProfits: (row['take_profits'] as List<dynamic>? ?? const [])
            .map((value) => _number(value)).toList(),
        weeklyBias: Bias.fromWire(row['weekly_bias'] as String? ?? ''),
        dailyBias: Bias.fromWire(row['daily_bias'] as String? ?? ''),
        session: TradingSession.fromWire(row['session'] as String? ?? ''),
        confluenceScore: row['confluence_score'] as int? ?? 0,
        confluenceMaximum: row['confluence_max'] as int? ?? 0,
        status: SetupStatus.fromWire(row['status'] as String),
        detectedAt: DateTime.parse(row['detected_at'] as String),
        notes: row['notes'] as String?,
        chartImageUrl: row['chart_image_url'] as String?,
        reviewedAt: row['reviewed_at'] == null
            ? null : DateTime.parse(row['reviewed_at'] as String),
        reviewedBy: row['reviewed_by'] as String?,
        rejectionReason: row['rejection_reason'] as String?,
        editedBeforeApproval: row['edited_before_approval'] as bool? ?? false,
      );
}
