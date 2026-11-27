import 'dart:async';
import '../../scanner/data/api_scanner_service.dart' show pollingStream;
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exceptions.dart';
import '../domain/licence.dart';
import '../domain/licence_enums.dart';
import 'licence_service.dart';

/// [LicenceService] backed by the CodePhantom backend (`/api/v1/licences`).
///
/// All endpoints require authentication. Generate/revoke/renew/suspend
/// additionally require `licences.manage` — the OWNER role has it.
class ApiLicenceService implements LicenceService {
  ApiLicenceService(this._client, {this.pollInterval = const Duration(seconds: 30)});

  final ApiClient _client;
  final Duration pollInterval;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  Future<List<Licence>> _fetchAll() async {
    final response = await _client.get('/licences');
    final List<dynamic> raw = response['data'] as List<dynamic>? ?? [];
    return raw.map((item) => Licence.fromBackendJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Stream<List<Licence>> watchLicences({String? userId}) => pollingStream(
        () => _fetchAll(),
        pollInterval: pollInterval,
        refresh: _changed.stream,
      );

  @override
  Future<Licence> generate({
    required String userId,
    required String product,
    required LicenceDuration duration,
    required int maxDevices,
  }) async {
    final planCode = switch (product.toLowerCase()) {
      'scanner' => 'SCANNER',
      'signals' => 'SIGNALS',
      'ea' => 'EA',
      _ => product.toUpperCase(),
    };

    final response = await _client.post(
      '/licences',
      body: {
        'user_id': userId,
        'service': planCode,
        'device_limit': maxDevices,
        'expires_at': duration.asDuration != null
            ? DateTime.now().add(duration.asDuration!).toIso8601String()
            : null,
      },
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final licenceRaw = data['licence'] as Map<String, dynamic>? ?? response;
    final plaintextKey = data['licence_key'] as String?;

    if (plaintextKey == null) throw const ServerException('No licence key returned');

    final licence = Licence(
      id: licenceRaw['id'] as String? ?? plaintextKey,
      key: plaintextKey,
      userId: userId,
      product: product,
      createdAt: DateTime.now(),
      expiresAt: duration.asDuration != null ? DateTime.now().add(duration.asDuration!) : null,
      maxDevices: maxDevices,
      activeDevices: 0,
      status: LicenceStatus.unactivated,
    );

    _changed.add(null);
    return licence;
  }

  @override
  Future<Licence> revoke(String licenceId) async {
    final response = await _client.post('/licences/$licenceId/revoke');
    return Licence.fromBackendJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<Licence> renew(String licenceId, LicenceDuration duration) async {
    final response = await _client.post(
      '/licences/$licenceId/renew',
      body: {
        'expires_at': duration.asDuration != null
            ? DateTime.now().add(duration.asDuration!).toIso8601String()
            : null,
      },
    );
    return Licence.fromBackendJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<Licence> suspend(String licenceId) async {
    final response = await _client.post('/licences/$licenceId/suspend');
    return Licence.fromBackendJson(response['data'] as Map<String, dynamic>);
  }
}
