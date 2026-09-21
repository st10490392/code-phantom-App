import '../../../core/permissions/app_role.dart';
import '../../../core/permissions/permission_set.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.permissions,
  });

  final String id;
  final String email;
  final String displayName;
  final AppRole role;
  final PermissionSet permissions;

  /// OWNER always has full effective access regardless of the stored
  /// permission set (see docs/ARCHITECTURE.md §5).
  bool get isOwner => role == AppRole.owner;

  AuthUser copyWith({
    String? id,
    String? email,
    String? displayName,
    AppRole? role,
    PermissionSet? permissions,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      role: AppRole.fromWire(json['role'] as String),
      permissions: PermissionSet.fromWire(json['permissions'] as List<dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'role': role.wireValue,
        'permissions': permissions.toWire(),
      };
}
