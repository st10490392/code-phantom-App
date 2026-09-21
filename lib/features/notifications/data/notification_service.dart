import '../domain/app_notification.dart';

/// Stream-based so adding real push notifications later (FCM) only means
/// feeding this same stream from a push payload — no presentation changes.
abstract class NotificationService {
  Stream<List<AppNotification>> watchNotifications();

  Future<void> markRead(String notificationId);

  Future<void> markAllRead();

  /// Pushes a new in-app event (e.g. "Setup approved", "Signal created
  /// from approved setup") onto the notification stream. Other modules'
  /// controllers call this to surface a workflow outcome — this is not a
  /// push notification (no FCM yet), just an in-app one.
  Future<void> notify(AppNotification notification);
}
