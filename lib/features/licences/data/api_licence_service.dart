import 'dart:async';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exceptions.dart';
import '../../scanner/data/api_scanner_service.dart' show pollingStream;
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

  /// Backend page size, matching `listLicencesQuerySchema`'s `limit` ceiling.
  static const _pageSize = 200;

  Future<List<Licence>> _fetchAll({String? userId}) async {
    final response = await _client.get(
      '/licences',
      query: {'limit': _pageSize, if (userId != null) 'user_id': userId},
    );
    final List<dynamic> raw = response['data'] as List<dynamic>? ?? [];
    return raw.map((item) => Licence.fromBackendJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Stream<List<Licence>> watchLicences({String? userId}) => pollingStream(
        () => _fetchAll(userId: userId),
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
    final service = switch (product.toLowerCase()) {
      'scanner' => 'SCANNER',
      'signals' => 'SIGNALS',
      'ea' => 'EA',
      _ => product.toUpperCase(),
    };

    // `expires_at` is optional in the backend schema and rejects `null`, so a
    // lifetime licence omits the key instead of sending null.
    final body = <String, dynamic>{
      'user_id': userId,
      'service': service,
      'device_limit': maxDevices,
      if (duration.asDuration != null) 'expires_at': _expiryFor(duration),
    };
    final response = await _client.post('/licences', body: body);

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final licenceRaw = data['licence'] as Map<String, dynamic>?;
    // The plaintext key is returned exactly once, by this response; it is
    // never retrievable again, so it is shown here and never persisted.
    final plaintextKey = data['licence_key'] as String?;
    if (licenceRaw == null || plaintextKey == null) {
      throw const ServerException('The backend did not return a new licence key.');
    }

    final licence = Licence.fromBackendJson(licenceRaw).copyWith(key: plaintextKey);
    _changed.add(null);
    return licence;
  }

  @override
  Future<Licence> revoke(String licenceId) async {
    final response = await _client.post('/licences/${Uri.encodeComponent(licenceId)}/revoke');
    return Licence.fromBackendJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<Licence> renew(String licenceId, LicenceDuration duration) async {
    // `POST /licences/:id/renew` requires a concrete `expires_at` — a lifetime
    // licence has nothing to extend, so refuse locally rather than sending a
    // body the backend would reject with 400.
    if (duration.asDuration == null) {
      throw const ValidationException('A lifetime licence has no expiry to renew.');
    }
    final response = await _client.post(
      '/licences/${Uri.encodeComponent(licenceId)}/renew',
      body: {'expires_at': _expiryFor(duration)},
    );
    return Licence.fromBackendJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<Licence> suspend(String licenceId) async {
    final response = await _client.post('/licences/${Uri.encodeComponent(licenceId)}/suspend');
    return Licence.fromBackendJson(response['data'] as Map<String, dynamic>);
  }

  static String _expiryFor(LicenceDuration duration) =>
      DateTime.now().add(duration.asDuration!).toUtc().toIso8601String();
}
