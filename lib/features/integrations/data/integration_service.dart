import '../domain/integration.dart';

/// Interface for managing platform integrations.
///
/// Only OWNER users with `integrations.manage` permission may access these
/// operations. All mutating endpoints require authentication and authorization
/// which is enforced server-side; this interface is a client-side contract.
abstract class IntegrationService {
  /// Fetches all integrations visible to the current user.
  Stream<List<Integration>> watchIntegrations();

  /// Creates a new SCANNER_PUBLISHER integration with `scanner.publish` scope.
  ///
  /// Returns the created integration with the plaintext secret (shown once).
  /// The secret must never be logged or persisted by the client.
  Future<Integration> createScannerPublisher({
    required String name,
  });

  /// Revokes an integration by ID.
  ///
  /// Requires confirmation from the user before calling.
  Future<Integration> revoke(String integrationId);
}