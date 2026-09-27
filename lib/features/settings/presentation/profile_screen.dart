import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const EmptyView(message: 'Not signed in.')
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                PhantomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(context, 'Name', user.displayName),
                      _row(context, 'Email', user.email),
                      _row(context, 'Role', user.role.label),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Granted permissions', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: user.isOwner
                      ? [const PhantomChip(label: 'ALL (OWNER)')]
                      : [
                          for (final p in user.permissions.granted)
                            PhantomChip(label: p.wireValue.replaceAll('_', ' ')),
                        ],
                ),
              ],
            ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.mutedText)),
          const SizedBox(width: AppSpacing.md),
          // Long values (e.g. an email address on a narrow phone) wrap
          // instead of overflowing.
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}
