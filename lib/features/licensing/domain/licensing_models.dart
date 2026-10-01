class CoreLicence {
  const CoreLicence({
    required this.id,
    required this.keyPrefix,
    required this.status,
    required this.planCode,
    required this.deviceLimit,
    required this.createdAt,
    this.userId,
    this.redeemedAt,
    this.expiresAt,
  });

  final String id;
  final String keyPrefix;
  final String status;
  final String planCode;
  final int deviceLimit;
  final DateTime createdAt;
  final String? userId;
  final DateTime? redeemedAt;
  final DateTime? expiresAt;

  factory CoreLicence.fromJson(Map<String, dynamic> json) => CoreLicence(
        id: json['id'] as String,
        keyPrefix: json['key_prefix'] as String? ?? '—',
        status: json['status'] as String? ?? 'UNKNOWN',
        planCode: json['plan_code'] as String? ?? 'unknown',
        deviceLimit: json['device_limit'] as int? ?? 1,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        userId: json['user_id'] as String?,
        redeemedAt: DateTime.tryParse(json['redeemed_at'] as String? ?? ''),
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      );
}

class GeneratedActivationKey {
  const GeneratedActivationKey({
    required this.activationKey,
    required this.licence,
  });

  final String activationKey;
  final CoreLicence licence;

  factory GeneratedActivationKey.fromJson(Map<String, dynamic> json) =>
      GeneratedActivationKey(
        activationKey: json['activation_key'] as String,
        licence: CoreLicence.fromJson(json['licence'] as Map<String, dynamic>),
      );
}

class ActivationResult {
  const ActivationResult({
    required this.deviceId,
    required this.entitlements,
  });

  final String deviceId;
  final List<String> entitlements;
}
