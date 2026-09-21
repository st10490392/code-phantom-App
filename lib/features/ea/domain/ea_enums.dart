enum EAConnectionStatus {
  online,
  offline;

  String get wireValue => this == EAConnectionStatus.online ? 'ONLINE' : 'OFFLINE';
  static EAConnectionStatus fromWire(String v) =>
      v == 'ONLINE' ? EAConnectionStatus.online : EAConnectionStatus.offline;
}

enum RiskMode {
  standard,
  propFirm,
  aggressive;

  String get wireValue => switch (this) {
        RiskMode.standard => 'STANDARD',
        RiskMode.propFirm => 'PROP_FIRM',
        RiskMode.aggressive => 'AGGRESSIVE',
      };

  static RiskMode fromWire(String v) => switch (v) {
        'PROP_FIRM' => RiskMode.propFirm,
        'AGGRESSIVE' => RiskMode.aggressive,
        _ => RiskMode.standard,
      };
}
