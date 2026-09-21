/// Fine-grained permissions. Independent from [AppRole] — two users with
/// the same role can have different permission sets (see brief's
/// User A / User B example).
enum Permission {
  scannerAccess,
  scannerReview, // approve/reject/edit pending setups
  signalsAccess,
  eaAccess,
  eaControl, // pause/resume/risk changes/emergency stop
  clientAdmin, // view/manage clients
  licenceAdmin, // generate/revoke/renew licences
  systemAdmin; // limited system controls, below OWNER

  String get wireValue => switch (this) {
        Permission.scannerAccess => 'SCANNER_ACCESS',
        Permission.scannerReview => 'SCANNER_REVIEW',
        Permission.signalsAccess => 'SIGNALS_ACCESS',
        Permission.eaAccess => 'EA_ACCESS',
        Permission.eaControl => 'EA_CONTROL',
        Permission.clientAdmin => 'CLIENT_ADMIN',
        Permission.licenceAdmin => 'LICENCE_ADMIN',
        Permission.systemAdmin => 'SYSTEM_ADMIN',
      };

  static Permission? fromWire(String value) {
    for (final p in Permission.values) {
      if (p.wireValue == value) return p;
    }
    return null;
  }
}
