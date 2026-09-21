import '../../../core/permissions/permission_set.dart';

enum ClientAccountStatus {
  active,
  suspended,
  disabled;

  String get wireValue => switch (this) {
        ClientAccountStatus.active => 'ACTIVE',
        ClientAccountStatus.suspended => 'SUSPENDED',
        ClientAccountStatus.disabled => 'DISABLED',
      };
}

class RegisteredDevice {
  const RegisteredDevice({required this.id, required this.label, required this.lastSeen});
  final String id;
  final String label;
  final DateTime lastSeen;
}

class ClientProfile {
  const ClientProfile({
    required this.userId,
    required this.name,
    required this.email,
    required this.status,
    required this.joinedAt,
    required this.lastLoginAt,
    required this.servicePermissions,
    required this.licenceStatus,
    this.licenceExpiry,
    required this.registeredDevices,
  });

  final String userId;
  final String name;
  final String email;
  final ClientAccountStatus status;
  final DateTime joinedAt;
  final DateTime lastLoginAt;
  final PermissionSet servicePermissions;

  /// Mirrors `Licence.status.wireValue` for display without a hard model dependency.
  final String licenceStatus;
  final DateTime? licenceExpiry;
  final List<RegisteredDevice> registeredDevices;

  ClientProfile copyWith({
    ClientAccountStatus? status,
    PermissionSet? servicePermissions,
  }) {
    return ClientProfile(
      userId: userId,
      name: name,
      email: email,
      status: status ?? this.status,
      joinedAt: joinedAt,
      lastLoginAt: lastLoginAt,
      servicePermissions: servicePermissions ?? this.servicePermissions,
      licenceStatus: licenceStatus,
      licenceExpiry: licenceExpiry,
      registeredDevices: registeredDevices,
    );
  }
}
