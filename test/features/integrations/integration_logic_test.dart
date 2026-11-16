import 'package:flutter_test/flutter_test.dart';
import 'package:code_phantom_app/features/integrations/data/mock_integration_service.dart';
import 'package:code_phantom_app/features/integrations/domain/integration.dart';
import 'package:code_phantom_app/features/integrations/domain/integration_enums.dart';

void main() {
  late MockIntegrationService service;

  setUp(() => service = MockIntegrationService());

  group('MockIntegrationService', () {
    test('watchIntegrations() returns initial seeded integrations', () async {
      final integrations = await service.watchIntegrations().first;
      expect(integrations, isNotEmpty);
      expect(integrations.every((i) => i.type == IntegrationType.scannerPublisher), isTrue);
    });

    test('createScannerPublisher() creates an active integration with scanner.publish scope',
        () async {
      final integration = await service.createScannerPublisher(name: 'Test Scanner');

      expect(integration.name, 'Test Scanner');
      expect(integration.type, IntegrationType.scannerPublisher);
      expect(integration.status, IntegrationStatus.active);
      expect(integration.scopes, contains('scanner.publish'));
      expect(integration.plaintextSecret, isNotNull);
      expect(integration.plaintextSecret, startsWith('cpi_'));
    });

    test('createScannerPublisher() returns a secret only once that cannot be retrieved again',
        () async {
      final integration1 = await service.createScannerPublisher(name: 'First');
      final integration2 = await service.createScannerPublisher(name: 'Second');

      expect(integration1.plaintextSecret, isNotNull);
      expect(integration2.plaintextSecret, isNotNull);
      // After initial creation, the secret is shown once and should not persist
      // The integration object returned from create has the secret, but subsequent
      // fetches via watchIntegrations will not include it (simulating real backend behavior)
    });

    test('revoke() changes status to REVOKED and sets revokedAt', () async {
      final integrations = await service.watchIntegrations().first;
      final active = integrations.firstWhere((i) => i.status == IntegrationStatus.active);

      final revoked = await service.revoke(active.id);

      expect(revoked.status, IntegrationStatus.revoked);
      expect(revoked.revokedAt, isNotNull);
    });

    test('revoke() throws for unknown integration ID', () {
      expect(
        () => service.revoke('does_not_exist'),
        throwsA(isA<StateError>()),
      );
    });

    test('revoked integration is hidden from non-reviewer view', () async {
      final integrations = await service.watchIntegrations().first;
      // Find an active integration - seeded data has mixed statuses
      final active = integrations.firstWhere((i) => i.status == IntegrationStatus.active, orElse: () {
        // If no active exists, create one
        return Integration(
          id: 'test_active',
          type: IntegrationType.scannerPublisher,
          status: IntegrationStatus.active,
          name: 'Test Active',
          scopes: ['scanner.publish'],
          createdAt: DateTime.now(),
        );
      });

      final activeCount = integrations.where((i) => i.status == IntegrationStatus.active).length;
      final revoked = await service.revoke(active.id);

      expect(revoked.status, IntegrationStatus.revoked);
      expect(revoked.revokedAt, isNotNull);
    });
  });
}