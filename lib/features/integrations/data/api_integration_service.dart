import 'dart:async';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_exceptions.dart';
import '../../scanner/data/api_scanner_service.dart' show pollingStream;
import '../domain/integration.dart';
import '../domain/integration_enums.dart';
import 'integration_service.dart';

/// [IntegrationService] backed by the CodePhantom backend
/// (`/api/v1/admin/platform/integrations`).
///
/// All endpoints require authentication and the `integrations.manage`
/// permission (OWNER-only). The plaintext secret is returned only on the
/// create response and must never be logged or persisted by the client.
class ApiIntegrationService implements IntegrationService {
  ApiIntegrationService(this._client, {this.pollInterval = const Duration(seconds: 30)});

  final ApiClient _client;
  final Duration pollInterval;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  @override
  Stream<List<Integration>> watchIntegrations() =>
      pollingStream(_fetchAll, pollInterval: pollInterval, refresh: _changed.stream);

  Future<List<Integration>> _fetchAll() async {
    final response = await _client.get('/admin/platform/integrations');
    final List<dynamic> raw = response['data'] as List<dynamic>? ?? [];
    return raw
        .map((item) => Integration.fromBackendJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Integration> createScannerPublisher({required String name}) async {
    final response = await _client.post(
      '/admin/platform/integrations',
      body: {
        'type': 'SCANNER_PUBLISHER',
        'name': name,
        'scopes': ['scanner.publish'],
      },
    );

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final integrationRaw = data['integration'] as Map<String, dynamic>?;
    final plaintextSecret = data['plaintext_secret'] as String?;

    if (integrationRaw == null || plaintextSecret == null) {
      throw const ServerException('The backend did not return a new integration secret.');
    }

    final integration = Integration.fromBackendJson(integrationRaw).copyWith(
      plaintextSecret: plaintextSecret,
    );
    _changed.add(null);
    return integration;
  }

  @override
  Future<Integration> revoke(String integrationId) async {
    // Backend returns 204 No Content on success
    await _client.post(
      '/admin/platform/integrations/${Uri.encodeComponent(integrationId)}/revoke',
    );
    // Return a minimal revoked integration object
    final integration = Integration(
      id: integrationId,
      type: IntegrationType.scannerPublisher,
      status: IntegrationStatus.revoked,
      name: '',
      scopes: const [],
      createdAt: DateTime.now(),
      revokedAt: DateTime.now(),
    );
    _changed.add(null);
    return integration;
  }
}