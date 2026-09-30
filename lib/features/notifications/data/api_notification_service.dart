import 'dart:async';
import '../../../core/network/api_client.dart';
import '../../scanner/data/api_scanner_service.dart' show pollingStream;
import '../domain/app_notification.dart';
import 'notification_service.dart';

class ApiNotificationService implements NotificationService {
  ApiNotificationService(this._client, {this.pollInterval = const Duration(seconds: 30)});

  final ApiClient _client;
  final Duration pollInterval;
  final StreamController<void> _changed = StreamController<void>.broadcast();

  Future<List<AppNotification>> _list() async {
    final response = await _client.get('/notifications', query: {'limit': 200});
    final rows = response['data'] as List<dynamic>? ?? const <dynamic>[];
    return rows
        .map((row) => notificationFromBackendJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Stream<List<AppNotification>> watchNotifications() =>
      pollingStream(_list, pollInterval: pollInterval, refresh: _changed.stream);

  @override
  Future<void> markRead(String notificationId) async {
    await _client.post('/notifications/${Uri.encodeComponent(notificationId)}/read');
    _changed.add(null);
  }

  @override
  Future<void> markAllRead() async {
    await _client.post('/notifications/read-all');
    _changed.add(null);
  }

  @override
  Future<void> notify(AppNotification notification) async {
    throw StateError('Client-side notification creation is not supported.');
  }
}

AppNotification notificationFromBackendJson(Map<String, dynamic> row) {
  final priority = switch (row['priority'] as String? ?? 'INFO') {
    'SUCCESS' => NotificationPriority.success,
    'WARNING' => NotificationPriority.warning,
    'CRITICAL' => NotificationPriority.critical,
    _ => NotificationPriority.info,
  };

  return AppNotification(
    id: row['id'] as String,
    title: row['title'] as String? ?? 'CodePhantom update',
    body: row['body'] as String? ?? '',
    priority: priority,
    category: (row['type'] as String? ?? 'general').toLowerCase(),
    createdAt: DateTime.parse(row['created_at'] as String),
    readAt: row['read_at'] == null ? null : DateTime.parse(row['read_at'] as String),
  );
}
