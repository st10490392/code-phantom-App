import 'dart:async';
import 'package:flutter/foundation.dart' show listEquals;
import '../../../core/network/api_client.dart';
import '../domain/scanner_enums.dart';
import '../domain/scanner_setup.dart';
import 'scanner_service.dart';

/// [ScannerService] backed by the CodePhantom backend (`/scanner/setups`).
///
/// The backend is the only source of truth: every list is fetched from it,
/// re-fetched on an interval and immediately after this client's own
/// approve/reject/edit, so a refresh or app restart always shows the
/// authoritative review state. Approval is a single backend transaction that
/// also creates the one Signal for the setup — this client never creates a
/// Signal itself.
///
/// Visibility is enforced server-side too: callers without `scanner.review`
/// only ever receive APPROVED setups whatever `status` they ask for.
class ApiScannerService implements ScannerService {
  ApiScannerService(this._client, {this.pollInterval = const Duration(seconds: 30)});

  final ApiClient _client;
  final Duration pollInterval;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  /// Backend page size; comfortably above the review queue's working set.
  static const _pageSize = 200;

  static String _path(String id, [String suffix = '']) => '/scanner/setups/${Uri.encodeComponent(id)}$suffix';

  Future<List<ScannerSetup>> _list(SetupStatus? status) async {
    // The backend has no CANCELLED/EXPIRED setup states.
    if (status == SetupStatus.cancelled || status == SetupStatus.expired) return const [];
    final response = await _client.get(
      '/scanner/setups',
      query: {'limit': _pageSize, if (status != null) 'status': status.wireValue},
    );
    return (response['data'] as List<dynamic>)
        .map((row) => ScannerSetup.fromBackendJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Stream<List<ScannerSetup>> watchSetups({SetupStatus? status}) =>
      pollingStream(() => _list(status), pollInterval: pollInterval, refresh: _changed.stream);

  @override
  Future<ScannerSetup?> getSetupById(String id) async {
    final response = await _client.get(_path(id));
    return ScannerSetup.fromBackendJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<ScannerSetup> approve(String setupId, {String? note, String? reviewedBy}) async {
    // Idempotent server-side: a repeat returns the existing Signal (200).
    final response = await _client.post(_path(setupId, '/approve'));
    final data = response['data'] as Map<String, dynamic>;
    _changed.add(null);
    return ScannerSetup.fromBackendJson(data['setup'] as Map<String, dynamic>);
  }

  @override
  Future<ScannerSetup> reject(String setupId, {required String reason, String? reviewedBy}) async {
    final response = await _client.post(_path(setupId, '/reject'), body: {'rejection_reason': reason});
    _changed.add(null);
    return ScannerSetup.fromBackendJson(response['data'] as Map<String, dynamic>);
  }

  /// Sends only fields the reviewer actually changed, against the current
  /// server copy. Detection metadata (market, broker symbol, detected time,
  /// strategy profile, external id) is never sent; on scanner-published
  /// setups symbol/timeframe/direction are immutable and the backend refuses
  /// them with 409 IMMUTABLE_FIELD.
  @override
  Future<ScannerSetup> update(ScannerSetup setup) async {
    final current = (await getSetupById(setup.id))!;
    final body = editRequestBody(current, setup);
    if (body.isEmpty) return current;
    final response = await _client.patch(_path(setup.id), body: body);
    _changed.add(null);
    return ScannerSetup.fromBackendJson(response['data'] as Map<String, dynamic>);
  }

  /// The PATCH body for turning [current] into [edited]: changed editable
  /// fields only.
  static Map<String, dynamic> editRequestBody(ScannerSetup current, ScannerSetup edited) {
    return {
      if (edited.timeframe != current.timeframe) 'timeframe': edited.timeframe,
      if (edited.direction != current.direction) 'direction': edited.direction.wireValue,
      if (edited.entry != current.entry) 'entry': edited.entry,
      if (edited.stopLoss != current.stopLoss) 'stop_loss': edited.stopLoss,
      if (!listEquals(edited.takeProfits, current.takeProfits)) 'take_profits': edited.takeProfits,
      if (edited.notes != current.notes) 'notes': edited.notes,
    };
  }
}

/// Emits [load]'s result on listen, every [pollInterval], and whenever
/// [refresh] fires. Only the newest request's result is emitted, so a slow
/// older response can never overwrite a fresher one. A failure of the first
/// load is surfaced as a stream error; a failed background refresh keeps the
/// last authoritative value on screen instead of blanking it.
Stream<T> pollingStream<T>(
  Future<T> Function() load, {
  required Duration pollInterval,
  required Stream<void> refresh,
}) {
  late final StreamController<T> out;
  Timer? timer;
  StreamSubscription<void>? refreshSub;
  var issued = 0;
  var delivered = false;

  Future<void> fetch() async {
    final ticket = ++issued;
    try {
      final value = await load();
      if (ticket == issued && !out.isClosed) {
        delivered = true;
        out.add(value);
      }
    } catch (e, st) {
      if (!delivered && ticket == issued && !out.isClosed) out.addError(e, st);
    }
  }

  out = StreamController<T>(
    onListen: () {
      fetch();
      timer = Timer.periodic(pollInterval, (_) => fetch());
      refreshSub = refresh.listen((_) => fetch());
    },
    onCancel: () async {
      timer?.cancel();
      await refreshSub?.cancel();
    },
  );
  return out.stream;
}
