import 'dart:async';
import '../domain/app_notification.dart';
import 'notification_service.dart';

class MockNotificationService implements NotificationService {
  MockNotificationService() {
    _notifications = List.of(_seed);
    _controller = StreamController<List<AppNotification>>.broadcast(
      onListen: () => _controller.add(List.unmodifiable(_notifications)),
    );
  }

  late final List<AppNotification> _notifications;
  late final StreamController<List<AppNotification>> _controller;

  @override
  Stream<List<AppNotification>> watchNotifications() => _controller.stream;

  @override
  Future<void> markRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;
    _notifications[index] = _notifications[index].copyWith(readAt: DateTime.now());
    _controller.add(List.unmodifiable(_notifications));
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(readAt: DateTime.now());
      }
    }
    _controller.add(List.unmodifiable(_notifications));
  }

  static final List<AppNotification> _seed = [
    AppNotification(
      id: 'notif_1',
      title: 'New scanner setup detected',
      body: 'GBPUSD M30 BUY — confluence 5/6.',
      priority: NotificationPriority.info,
      category: 'scanner',
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
      relatedEntityId: 'setup_001',
    ),
    AppNotification(
      id: 'notif_2',
      title: 'Signal approved',
      body: 'XAUUSD SELL approved and ready to publish.',
      priority: NotificationPriority.success,
      category: 'signals',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      relatedEntityId: 'signal_001',
    ),
    AppNotification(
      id: 'notif_3',
      title: 'TP1 reached',
      body: 'XAUUSD SELL hit TP1.',
      priority: NotificationPriority.success,
      category: 'signals',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      readAt: DateTime.now().subtract(const Duration(hours: 1)),
      relatedEntityId: 'signal_001',
    ),
    AppNotification(
      id: 'notif_4',
      title: 'EA went offline',
      body: 'Live — Personal (IC Markets) lost connection.',
      priority: NotificationPriority.warning,
      category: 'ea',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      relatedEntityId: 'ea_002',
    ),
    AppNotification(
      id: 'notif_5',
      title: 'Drawdown warning',
      body: 'FTMO Challenge #1 daily drawdown at 0.7%.',
      priority: NotificationPriority.warning,
      category: 'ea',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      relatedEntityId: 'ea_001',
    ),
    AppNotification(
      id: 'notif_6',
      title: 'Licence expiring',
      body: 'Signals-Only Client\'s licence expires in 4 days.',
      priority: NotificationPriority.warning,
      category: 'licences',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: 'notif_7',
      title: 'Licence expired',
      body: 'EA-Only Client\'s licence has expired.',
      priority: NotificationPriority.critical,
      category: 'licences',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    AppNotification(
      id: 'notif_8',
      title: 'New device activated',
      body: 'Scanner-Only Client activated a new device (Pixel 8).',
      priority: NotificationPriority.info,
      category: 'devices',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
}
