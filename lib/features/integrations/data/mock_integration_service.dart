import 'dart:async';
import 'package:flutter/foundation.dart' show listEquals;
import '../../../scanner/data/api_scanner_service.dart' show pollingStream;
import '../domain/integration.dart';
import '../domain/integration_enums.dart';
import 'integration_service.dart';

/// Mock [IntegrationService] for development and testing.
///
/// Holds state in-memory; survives across navigation but resets on hot restart.
class MockIntegrationService implements IntegrationService {
  MockIntegrationService() {
    // Seed with a couple of sample integrations
    _integrations = [
      Integration(
        id: 'int_1',
        type: IntegrationType.scannerPublisher,
        status: IntegrationStatus.active,
        name: 'Production Scanner',
        scopes: ['scanner.publish'],
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        lastUsedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Integration(
        id: 'int_2',
        type: IntegrationType.scannerPublisher,
        status: IntegrationStatus.revoked,
        name: 'Staging Scanner (revoked)',
        scopes: ['scanner.publish'],
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        revokedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];
  }

  final List<Integration> _integrations;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  @override
  Stream<List<Integration>> watchIntegrations() =>
      pollingStream(() => _fetchAll(), pollInterval: const Duration(seconds: 30), refresh: _changed.stream);

  Future<List<Integration>> _fetchAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_integrations);
  }

  @override
  Future<Integration> createScannerPublisher({required String name}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    // Generate a mock secret that looks like a real integration key
    final secret = 'cpi_${_generateSecret(32)}';
    final now = DateTime.now();
    final integration = Integration(
      id: 'int_${_integrations.length + 1}',
      type: IntegrationType.scannerPublisher,
      status: IntegrationStatus.active,
      name: name,
      scopes: ['scanner.publish'],
      createdAt: now,
      plaintextSecret: secret,
    );
    _integrations.add(integration);
    _changed.add(null);
    return integration;
  }

  @override
  Future<Integration> revoke(String integrationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final index = _integrations.indexWhere((i) => i.id == integrationId);
    if (index == -1) {
      throw StateError('Integration not found: $integrationId');
    }
    final revoked = _integrations[index].copyWith(
      status: IntegrationStatus.revoked,
      revokedAt: DateTime.now(),
    );
    _integrations[index] = revoked;
    _changed.add(null);
    return revoked;
  }

  String _generateSecret(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    var seed = random;
    for (var i = 0; i < length; i++) {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
      buffer.write(chars[seed % chars.length]);
    }
    return buffer.toString();
  }
}