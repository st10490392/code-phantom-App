enum EAConnectionStatus {
  online,
  offline;

  String get wireValue => this == EAConnectionStatus.online ? 'ONLINE' : 'OFFLINE';
  static EAConnectionStatus fromWire(String v) =>
      v == 'ONLINE' ? EAConnectionStatus.online : EAConnectionStatus.offline;
}

enum RiskMode {
  conservative,
  moderate,
  aggressive,
  prop,
  custom;

  String get wireValue => switch (this) {
        RiskMode.conservative => 'CONSERVATIVE',
        RiskMode.moderate => 'MODERATE',
        RiskMode.aggressive => 'AGGRESSIVE',
        RiskMode.prop => 'PROP',
        RiskMode.custom => 'CUSTOM',
      };

  static RiskMode fromWire(String v) => switch (v) {
        'CONSERVATIVE' => RiskMode.conservative,
        'AGGRESSIVE' => RiskMode.aggressive,
        'PROP' || 'PROP_FIRM' => RiskMode.prop,
        'CUSTOM' => RiskMode.custom,
        _ => RiskMode.moderate,
      };
}
