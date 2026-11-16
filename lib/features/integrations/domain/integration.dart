import 'integration_enums.dart';

/// Represents a platform integration (e.g., SCANNER_PUBLISHER) managed by an OWNER.
///
/// The plaintext secret is returned **only once** by the create endpoint and
/// must never be logged or persisted by the client. It is shown in a secure
/// modal with a one-time copy action, then discarded.
class Integration {
  const Integration({
    required this.id,
    required this.type,
    required this.status,
    required this.name,
    required this.scopes,
    required this.createdAt,
    this.revokedAt,
    this.lastUsedAt,
    this.plaintextSecret, // Only non-null immediately after creation
  });

  final String id;
  final IntegrationType type;
  final IntegrationStatus status;
  final String name;
  final List<String> scopes;
  final DateTime createdAt;
  final DateTime? revokedAt;
  final DateTime? lastUsedAt;
  final String? plaintextSecret;

  /// Creates an [Integration] from the backend JSON response.
  ///
  /// The backend returns `plaintext_secret` only on the create response.
  factory Integration.fromBackendJson(Map<String, dynamic> json) {
    return Integration(
      id: json['id'] as String,
      type: IntegrationType.fromWire(json['type'] as String) ??
          IntegrationType.scannerPublisher,
      status: IntegrationStatus.fromWire(json['status'] as String) ??
          IntegrationStatus.active,
      name: json['name'] as String? ?? '',
      scopes: (json['scopes'] as List<dynamic>?)
              ?.map((s) => s as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String)
          : null,
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'] as String)
          : null,
      plaintextSecret: json['plaintext_secret'] as String?,
    );
  }

  /// Creates a copy with the given fields replaced.
  Integration copyWith({
    String? id,
    IntegrationType? type,
    IntegrationStatus? status,
    String? name,
    List<String>? scopes,
    DateTime? createdAt,
    DateTime? revokedAt,
    DateTime? lastUsedAt,
    String? plaintextSecret,
  }) {
    return Integration(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      name: name ?? this.name,
      scopes: scopes ?? this.scopes,
      createdAt: createdAt ?? this.createdAt,
      revokedAt: revokedAt ?? this.revokedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      plaintextSecret: plaintextSecret ?? this.plaintextSecret,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.wireValue,
        'status': status.wireValue,
        'name': name,
        'scopes': scopes,
        'created_at': createdAt.toIso8601String(),
        if (revokedAt != null) 'revoked_at': revokedAt!.toIso8601String(),
        if (lastUsedAt != null) 'last_used_at': lastUsedAt!.toIso8601String(),
        if (plaintextSecret != null) 'plaintext_secret': plaintextSecret,
      };
}