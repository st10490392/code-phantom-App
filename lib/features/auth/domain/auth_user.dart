import '../../../core/permissions/app_role.dart';
import '../../../core/permissions/permission_set.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.permissions,
    this.status = 'ACTIVE',
    this.protected = false,
  });

  final String id;
  final String email;
  final String displayName;
  final AppRole role;
  final PermissionSet permissions;

  /// Server-reported profile status (e.g. `ACTIVE`, `SUSPENDED`,
  /// `DISABLED`) — a mock account is always `ACTIVE`. `requireAuth`
  /// middleware on the backend already rejects a non-`ACTIVE` account
  /// before a session can even be established, so this is informational
  /// (e.g. for an account/profile screen) rather than something the app
  /// re-checks — the backend remains the authority.
  final String status;

  /// True for an account the backend protects from role/permission removal
  /// (e.g. the last OWNER). Informational for the same reason as [status].
  final bool protected;

  /// OWNER always has full effective access regardless of the stored
  /// permission set (see docs/ARCHITECTURE.md §5).
  bool get isOwner => role == AppRole.owner;

  AuthUser copyWith({
    String? id,
    String? email,
    String? displayName,
    AppRole? role,
    PermissionSet? permissions,
    String? status,
    bool? protected,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      status: status ?? this.status,
      protected: protected ?? this.protected,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      role: AppRole.fromWire(json['role'] as String),
      permissions: PermissionSet.fromWire(json['permissions'] as List<dynamic>?),
      status: json['status'] as String? ?? 'ACTIVE',
      protected: json['protected'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'role': role.wireValue,
        'permissions': permissions.toWire(),
        'status': status,
        'protected': protected,
      };
}
