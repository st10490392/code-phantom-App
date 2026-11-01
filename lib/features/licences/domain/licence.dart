import 'licence_enums.dart';

class Licence {
  const Licence({
    required this.id,
    required this.key,
    required this.userId,
    required this.product,
    required this.createdAt,
    this.activatedAt,
    this.expiresAt,
    required this.maxDevices,
    required this.activeDevices,
    required this.status,
  });

  final String id;

  /// Visual formatting only, e.g. `CPT-SCN-7F4K-92MQ-X81P` — NEVER
  /// cryptographically meaningful. Real key generation/validation must
  /// happen server-side (see docs/ARCHITECTURE.md §8).
  final String key;
  final String userId;
  final String product;
  final DateTime createdAt;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final int maxDevices;
  final int activeDevices;
  final LicenceStatus status;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory Licence.fromBackendJson(Map<String, dynamic> json) {
    return Licence(
      id: json['id'] as String,
      key: json['plaintext_key'] as String? ?? json['key'] as String? ?? json['prefix'] as String,
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      product: json['plan_code'] as String? ?? json['product'] as String? ?? 'Unknown',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now() : DateTime.now(),
      activatedAt: json['activated_at'] != null ? DateTime.tryParse(json['activated_at'] as String) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null,
      maxDevices: (json['device_limit'] as int?) ?? (json['max_devices'] as int?) ?? 1,
      activeDevices: (json['active_devices'] as int?) ?? 0,
      status: LicenceStatus.values.firstWhere(
        (s) => s.wireValue == (json['status'] as String? ?? 'UNUSED'),
        orElse: () => LicenceStatus.unactivated,
      ),
    );
  }

  Licence copyWith({LicenceStatus? status, DateTime? expiresAt}) {
    return Licence(
      id: id,
      key: key,
      userId: userId,
      product: product,
      createdAt: createdAt,
      activatedAt: activatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      maxDevices: maxDevices,
      activeDevices: activeDevices,
      status: status ?? this.status,
    );
  }
}
