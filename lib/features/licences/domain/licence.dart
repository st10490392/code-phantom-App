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
    // `GET /licences` returns `public.licences` rows: the plaintext key is
    // never included (it is returned once, by the generate response), so the
    // display value here is the key prefix.
    return Licence(
      id: json['id'] as String,
      key: (json['key_prefix'] as String?) ??
          (json['plaintext_key'] as String?) ??
          (json['key'] as String?) ??
          '',
      userId: (json['user_id'] as String?) ?? (json['userId'] as String?) ?? '',
      product: (json['service'] as String?) ?? (json['plan_code'] as String?) ?? (json['product'] as String?) ?? 'Unknown',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      activatedAt: json['activated_at'] == null ? null : DateTime.tryParse(json['activated_at'] as String),
      expiresAt: json['expires_at'] == null ? null : DateTime.tryParse(json['expires_at'] as String),
      maxDevices: (json['device_limit'] as int?) ?? (json['max_devices'] as int?) ?? 1,
      activeDevices: (json['active_devices'] as int?) ?? 0,
      status: LicenceStatus.values.firstWhere(
        (s) => s.wireValue == (json['status'] as String? ?? 'UNACTIVATED'),
        orElse: () => LicenceStatus.unactivated,
      ),
    );
  }

  Licence copyWith({LicenceStatus? status, DateTime? expiresAt, String? key, int? activeDevices}) {
    return Licence(
      id: id,
      key: key ?? this.key,
      userId: userId,
      product: product,
      createdAt: createdAt,
      activatedAt: activatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      maxDevices: maxDevices,
      activeDevices: activeDevices ?? this.activeDevices,
      status: status ?? this.status,
    );
  }
}
