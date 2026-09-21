/// User roles. Roles describe *who* a user is, not what they can do —
/// see [PermissionSet] for the independent axis that decides access.
enum AppRole {
  owner,
  admin,
  trader,
  scannerClient,
  signalClient,
  eaClient,
  internal;

  String get label => switch (this) {
        AppRole.owner => 'Owner',
        AppRole.admin => 'Admin',
        AppRole.trader => 'Trader',
        AppRole.scannerClient => 'Scanner Client',
        AppRole.signalClient => 'Signal Client',
        AppRole.eaClient => 'EA Client',
        AppRole.internal => 'Internal',
      };

  static AppRole fromWire(String value) => AppRole.values.firstWhere(
        (r) => r.wireValue == value,
        orElse: () => AppRole.internal,
      );

  String get wireValue => switch (this) {
        AppRole.owner => 'OWNER',
        AppRole.admin => 'ADMIN',
        AppRole.trader => 'TRADER',
        AppRole.scannerClient => 'SCANNER_CLIENT',
        AppRole.signalClient => 'SIGNAL_CLIENT',
        AppRole.eaClient => 'EA_CLIENT',
        AppRole.internal => 'INTERNAL',
      };
}
