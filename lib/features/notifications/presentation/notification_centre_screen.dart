import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/app_notification.dart';
import 'notifications_providers.dart';

class NotificationCentreScreen extends ConsumerWidget {
  const NotificationCentreScreen({super.key});

  Color _priorityColor(NotificationPriority p) => switch (p) {
        NotificationPriority.info => AppColors.cyberBlue,
        NotificationPriority.success => AppColors.success,
        NotificationPriority.warning => AppColors.warning,
        NotificationPriority.critical => AppColors.critical,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationServiceProvider).markAllRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'Could not load notifications.\n$e'),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyView(
              icon: Icons.notifications_none,
              message: 'No notifications yet.',
            );
          }
          final sorted = [...notifications]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final n = sorted[i];
              return PhantomCard(
                raised: !n.isRead,
                onTap: () => ref.read(notificationServiceProvider).markRead(n.id),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: _priorityColor(n.priority),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(n.body, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
