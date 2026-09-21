import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mock_notification_service.dart';
import '../data/notification_service.dart';
import '../domain/app_notification.dart';

final notificationServiceProvider =
    Provider<NotificationService>((ref) => MockNotificationService());

final notificationListProvider = StreamProvider<List<AppNotification>>((ref) {
  return ref.watch(notificationServiceProvider).watchNotifications();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final async = ref.watch(notificationListProvider);
  return async.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});
