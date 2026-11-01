import 'dart:async';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exceptions.dart';
import '../domain/licence.dart';
import '../domain/licence_enums.dart';
import 'licence_service.dart';

/// [LicenceService] backed by the CodePhantom backend.
///
/// - `watchLicences()` polls `/me/licences`.
/// - `generate()` calls the admin endpoint `/admin/platform/licences/keys`.
/// - `revoke/renew/suspend` call the respective admin endpoints.
///
/// These endpoints require `licences.manage` permission. The OWNER role
/// has it by default; the backend enforces it regardless of what the
/// client sends.
class ApiLicenceService implements LicenceService {
  ApiLicenceService(this._client, {this.pollInterval = const Duration(seconds: 30)});

  final ApiClient _client;
  final Duration pollInterval;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  static const _base = '/me/licences';

  Future<List<Licence>> _fetchAll() async {
    final response = await _client.get(_base);
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
      '/admin/platform/licences/keys',
      body: {
        'plan_code': planCode,
        'count': 1,
        'device_limit': maxDevices,
        'source': 'ADMIN',
      },
    );

    final List<dynamic> keys = response['data'] as List<dynamic>? ?? [];
    if (keys.isEmpty) throw const AppException('No licence key returned');

    final raw = keys.first as Map<String, dynamic>;
    final licence = Licence(
      id: raw['id'] as String,
      key: raw['plaintext_key'] as String,
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
    final response = await _client.post('/admin/platform/licences/$licenceId/revoke', body: {'reason': 'Revoked from app'});
    return Licence.fromBackendJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<Licence> renew(String licenceId, LicenceDuration duration) async {
    final response = await _client.patch(
      '/admin/platform/licences/$licenceId',
      body: {'expires_at': duration.asDuration != null ? DateTime.now().add(duration.asDuration!).toIso8601String() : null},
    );
    return Licence.fromBackendJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<Licence> suspend(String licenceId) async {
    final response = await _client.post('/admin/platform/licences/$licenceId/suspend', body: {'reason': 'Suspended from app'});
    return Licence.fromBackendJson(response['data'] as Map<String, dynamic>);
  }
}
