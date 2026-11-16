enum IntegrationType {
  scannerPublisher('SCANNER_PUBLISHER'); // Type: scanner publisher integrations.

  const IntegrationType(this.wireValue);

  final String wireValue;

  static IntegrationType? fromWire(String value) {
    for (final t in IntegrationType.values) {
      if (t.wireValue == value) return t;
    }
    return null;
  }
}

enum IntegrationStatus {
  active('ACTIVE'),
  revoked('REVOKED');

  const IntegrationStatus(this.wireValue);

  final String wireValue;

  static IntegrationStatus? fromWire(String value) {
    for (final s in IntegrationStatus.values) {
      if (s.wireValue == value) return s;
    }
    return null;
  }
}