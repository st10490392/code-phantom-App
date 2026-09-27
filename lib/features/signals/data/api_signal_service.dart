import 'dart:async';
import '../../../core/network/api_client.dart';
import '../../scanner/data/api_scanner_service.dart' show pollingStream;
import '../../scanner/domain/scanner_setup.dart';
import '../domain/signal.dart';
import '../domain/signal_enums.dart';
import '../domain/signal_performance_summary.dart';
import 'signal_service.dart';

/// [SignalService] backed by the CodePhantom backend (`/signals`).
///
/// Signals are created only by the backend's scanner approval transaction
/// (exactly one per approved setup), so [createFromSetup] is refused here.
/// Clients without signals.publish/manage only receive published signals.
class ApiSignalService implements SignalService {
  ApiSignalService(this._client, {this.pollInterval = const Duration(seconds: 30)});

  final ApiClient _client;
  final Duration pollInterval;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  static const _pageSize = 200;

  Future<List<Signal>> _list(SignalStatus? status) async {
    // The backend has no PENDING signal state: a signal starts APPROVED.
    if (status == SignalStatus.pending) return const [];
    final response = await _client.get(
      '/signals',
      query: {'limit': _pageSize, if (status != null) 'status': status.wireValue},
    );
    return (response['data'] as List<dynamic>)
        .map((row) => signalFromBackendJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Stream<List<Signal>> watchSignals({SignalStatus? status}) =>
      pollingStream(() => _list(status), pollInterval: pollInterval, refresh: _changed.stream);

  @override
  Future<Signal> updateStatus(String signalId, SignalStatus status) async {
    final id = Uri.encodeComponent(signalId);
    final Map<String, dynamic> response;
    if (status == SignalStatus.published) {
      // In-app publish only; external channels are an explicit, separate choice.
      final result = await _client.post(
        '/signals/$id/publish',
        body: {
          'channels': ['APP'],
        },
      );
      response = {'data': (result['data'] as Map<String, dynamic>)['signal']};
    } else if (status == SignalStatus.pending || status == SignalStatus.approved) {
      throw StateError('A signal cannot be moved back to ${status.wireValue}.');
    } else {
      response = await _client.patch('/signals/$id/status', body: {'status': status.wireValue});
    }
    _changed.add(null);
    return signalFromBackendJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<SignalPerformanceSummary> performanceSummary() async {
    final closed = (await _list(null)).where((s) => s.status.isClosed).toList();
    final wins = closed.where((s) => s.result == 'WIN').length;
    final losses = closed.where((s) => s.result == 'LOSS').length;
    final rValues = closed.map((s) => s.rMultiple ?? 0).toList();
    return SignalPerformanceSummary(
      totalSignals: closed.length,
      wins: wins,
      losses: losses,
      winRatePercent: closed.isEmpty ? 0 : (wins / closed.length) * 100,
      averageRMultiple: rValues.isEmpty ? 0 : rValues.reduce((a, b) => a + b) / rValues.length,
    );
  }

  @override
  Future<Signal> createFromSetup(ScannerSetup setup) {
    throw UnsupportedError('Signals are created by the backend when a setup is approved.');
  }
}

/// Decodes a `public.signals` row (`numeric` scalars arrive as strings).
Signal signalFromBackendJson(Map<String, dynamic> row) {
  final rMultiple = row['r_multiple'];
  return Signal(
    id: row['id'] as String,
    setupId: row['source_setup_id'] as String?,
    symbol: row['symbol'] as String,
    direction: SetupDirection.fromWire(row['direction'] as String),
    entry: parseWireDecimal(row['entry']),
    stopLoss: parseWireDecimal(row['stop_loss']),
    takeProfits: (row['take_profits'] as List<dynamic>? ?? const []).map(parseWireDecimal).toList(growable: false),
    status: SignalStatus.fromWire(row['status'] as String),
    // Signals carry no session on the backend.
    session: TradingSession.unknown,
    openedAt: DateTime.parse((row['published_at'] ?? row['created_at']) as String),
    closedAt: row['closed_at'] == null ? null : DateTime.parse(row['closed_at'] as String),
    result: row['result'] as String?,
    rMultiple: rMultiple == null ? null : parseWireDecimal(rMultiple),
    notes: row['notes'] as String?,
  );
}
