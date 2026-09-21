import '../domain/app_notification.dart';

/// Stream-based so adding real push notifications later (FCM) only means
/// feeding this same stream from a push payload — no presentation changes.
abstract class NotificationService {
  Stream<List<AppNotification>> watchNotifications();

  Future<void> markRead(String notificationId);

  Future<void> markAllRead();
}
