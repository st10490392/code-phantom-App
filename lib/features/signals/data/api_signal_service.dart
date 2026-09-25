import '../../../core/network/api_client.dart';
import '../../scanner/domain/scanner_setup.dart';
import '../domain/signal.dart';
import '../domain/signal_enums.dart';
import '../domain/signal_performance_summary.dart';
import 'signal_service.dart';

/// Backend signal history; no publishing or status mutations before backtests.
class ApiSignalService implements SignalService {
  ApiSignalService(this._client);
  final ApiClient _client;

  Future<List<Signal>> _list(SignalStatus? status) async {
    final response = await _client.get('/signals', query: {
      'limit': 200,
      if (status != null && status != SignalStatus.pending)
        'status': status.wireValue,
    });
    final rows = response['data'] as List<dynamic>;
    final signals = rows.map((row) => _decode(row as Map<String, dynamic>)).toList();
    return status == null ? signals : signals.where((s) => s.status == status).toList();
  }

  @override
  Stream<List<Signal>> watchSignals({SignalStatus? status}) async* {
    yield await _list(status);
    yield* Stream.periodic(const Duration(seconds: 30))
        .asyncMap((_) => _list(status));
  }

  @override
  Future<Signal> updateStatus(String signalId, SignalStatus status) =>
      Future.error(StateError('Signal management is paused until backtests pass.'));

  @override
  Future<Signal> createFromSetup(ScannerSetup setup) =>
      Future.error(StateError('Only the backend can create a signal from an approved setup.'));

  @override
  Future<SignalPerformanceSummary> performanceSummary() async {
    final signals = await _list(null);
    final closed = signals.where((s) => s.status.isClosed).toList();
    final wins = closed.where((s) => s.result == 'WIN').length;
    final losses = closed.where((s) => s.result == 'LOSS').length;
    final measured = closed.where((s) => s.rMultiple != null).toList();
    final totalR = measured.fold<double>(0, (sum, s) => sum + s.rMultiple!);
    return SignalPerformanceSummary(
      totalSignals: closed.length,
      wins: wins,
      losses: losses,
      winRatePercent: wins + losses == 0 ? 0 : wins * 100 / (wins + losses),
      averageRMultiple: measured.isEmpty ? 0 : totalR / measured.length,
    );
  }

  double _number(Object? value) => value is num ? value.toDouble() : double.parse(value as String);

  Signal _decode(Map<String, dynamic> row) => Signal(
        id: row['id'] as String,
        setupId: row['source_setup_id'] as String?,
        symbol: row['symbol'] as String,
        direction: SetupDirection.fromWire(row['direction'] as String),
        entry: _number(row['entry']),
        stopLoss: _number(row['stop_loss']),
        takeProfits: (row['take_profits'] as List<dynamic>? ?? const [])
            .map(_number).toList(),
        status: SignalStatus.fromWire(row['status'] as String),
        session: TradingSession.unknown,
        openedAt: DateTime.parse(row['created_at'] as String),
        closedAt: row['closed_at'] == null
            ? null : DateTime.parse(row['closed_at'] as String),
        result: row['result'] as String?,
        rMultiple: row['r_multiple'] == null ? null : _number(row['r_multiple']),
        notes: row['notes'] as String?,
      );
}
