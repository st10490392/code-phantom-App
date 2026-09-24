/// User roles. Roles describe *who* a user is, not what they can do —
/// see [PermissionSet] for the independent axis that decides access.
enum AppRole {
  owner,
  admin,
  trader,
  scannerClient,
  signalClient,
  eaClient,
  client,
  internal;

  String get label => switch (this) {
        AppRole.owner => 'Owner',
        AppRole.admin => 'Admin',
        AppRole.trader => 'Trader',
        AppRole.scannerClient => 'Scanner Client',
        AppRole.signalClient => 'Signal Client',
        AppRole.eaClient => 'EA Client',
        AppRole.client => 'Client',
        AppRole.internal => 'Internal',
      };

  /// Unrecognized wire values (a future role this build doesn't know about
  /// yet) fail safely to INTERNAL, which never has default permissions of
  /// its own — see [defaultPermissionsFor]. This must never be reached for
  /// a real `CLIENT` account: that value is recognized directly below.
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
        AppRole.client => 'CLIENT',
        AppRole.internal => 'INTERNAL',
      };
}
