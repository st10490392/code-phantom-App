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
