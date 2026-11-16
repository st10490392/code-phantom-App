import '../domain/integration.dart';

/// Service for managing platform integrations (e.g., SCANNER_PUBLISHER).
abstract class IntegrationService {
  /// Stream of integrations visible to the current user.
  Stream<List<Integration>> watchIntegrations();

  /// Creates a new SCANNER_PUBLISHER integration and returns the integration
  /// with the plaintext secret (shown only once).
  ///
  /// The secret MUST be displayed to the user immediately and never logged
  /// or persisted.
  Future<Integration> createScannerPublisher({required String name});

  /// Revokes an integration. Returns the revoked integration.
  Future<Integration> revoke(String integrationId);
}