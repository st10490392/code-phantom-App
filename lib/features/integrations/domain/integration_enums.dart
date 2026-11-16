/// Integration type — currently only SCANNER_PUBLISHER is supported.
/// Matches the backend's `integration_type` enum.
enum IntegrationType {
  scannerPublisher;

  String get wireValue => switch (this) {
        IntegrationType.scannerPublisher => 'SCANNER_PUBLISHER',
      };

  static IntegrationType? fromWire(String value) {
    for (final t in IntegrationType.values) {
      if (t.wireValue == value) return t;
    }
    return null;
  }

  String get label => switch (this) {
        IntegrationType.scannerPublisher => 'Scanner Publisher',
      };

  String get description => switch (this) {
        IntegrationType.scannerPublisher =>
            'Publishes scanner setups to the CodePhantom backend with `scanner.publish` scope.',
      };
}

/// Integration status — mirrors the backend's `integration_status` enum.
enum IntegrationStatus {
  active,
  revoked;

  String get wireValue => switch (this) {
        IntegrationStatus.active => 'ACTIVE',
        IntegrationStatus.revoked => 'REVOKED',
      };

  static IntegrationStatus? fromWire(String value) {
    for (final s in IntegrationStatus.values) {
      if (s.wireValue == value) return s;
    }
    return null;
  }

  String get label => switch (this) {
        IntegrationStatus.active => 'Active',
        IntegrationStatus.revoked => 'Revoked',
      };
}