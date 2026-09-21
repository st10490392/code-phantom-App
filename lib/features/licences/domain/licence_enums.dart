enum LicenceStatus {
  active,
  expired,
  revoked,
  suspended,
  unactivated;

  String get wireValue => switch (this) {
        LicenceStatus.active => 'ACTIVE',
        LicenceStatus.expired => 'EXPIRED',
        LicenceStatus.revoked => 'REVOKED',
        LicenceStatus.suspended => 'SUSPENDED',
        LicenceStatus.unactivated => 'UNACTIVATED',
      };
}

enum LicenceDuration {
  sevenDays,
  thirtyDays,
  sixtyDays,
  ninetyDays,
  oneYear,
  lifetime,
  custom;

  String get label => switch (this) {
        LicenceDuration.sevenDays => '7 days',
        LicenceDuration.thirtyDays => '30 days',
        LicenceDuration.sixtyDays => '60 days',
        LicenceDuration.ninetyDays => '90 days',
        LicenceDuration.oneYear => '1 year',
        LicenceDuration.lifetime => 'Lifetime',
        LicenceDuration.custom => 'Custom',
      };

  Duration? get asDuration => switch (this) {
        LicenceDuration.sevenDays => const Duration(days: 7),
        LicenceDuration.thirtyDays => const Duration(days: 30),
        LicenceDuration.sixtyDays => const Duration(days: 60),
        LicenceDuration.ninetyDays => const Duration(days: 90),
        LicenceDuration.oneYear => const Duration(days: 365),
        LicenceDuration.lifetime => null, // no expiry
        LicenceDuration.custom => null, // caller supplies an explicit expiry
      };
}
