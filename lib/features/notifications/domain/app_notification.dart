enum NotificationPriority {
  info,
  success,
  warning,
  critical;

  String get wireValue => name.toUpperCase();
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.priority,
    required this.category,
    required this.createdAt,
    this.readAt,
    this.relatedEntityId,
  });

  final String id;
  final String title;
  final String body;
  final NotificationPriority priority;

  /// e.g. "scanner", "signals", "ea", "licences", "devices".
  final String category;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? relatedEntityId;

  bool get isRead => readAt != null;

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      priority: priority,
      category: category,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      relatedEntityId: relatedEntityId,
    );
  }
}
