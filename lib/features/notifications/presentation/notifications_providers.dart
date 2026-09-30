import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_environment.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/api_notification_service.dart';
import '../data/mock_notification_service.dart';
import '../data/notification_service.dart';
import '../domain/app_notification.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) =>
    ref.watch(appEnvironmentProvider) == AppEnvironment.mock
        ? MockNotificationService()
        : ApiNotificationService(ref.watch(apiClientProvider)),
);

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
