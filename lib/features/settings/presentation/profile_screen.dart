import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/device/device_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../licences/presentation/activate_licence_sheet.dart';
import '../../licences/presentation/licence_activation_providers.dart';
import '../../live_feed/data/live_feed_service.dart';
import '../../live_feed/presentation/live_feed_providers.dart';

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
                const _LicenceDeviceCard(),
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

/// Device binding, stated as the backend actually reports it. The identifier
/// shown is this app's own generated UUID (the backend stores only its hash);
/// the bridge's hardware binding is shown separately because it belongs to the
/// second, distinct licence system.
class _LicenceDeviceCard extends ConsumerWidget {
  const _LicenceDeviceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bound = ref.watch(deviceBoundProvider).value ?? false;
    final deviceId = ref.watch(deviceIdProvider).value;
    final signalsKey = ref.watch(bridgeSignalsKeyActiveProvider).value ?? false;
    final feedStatus = ref.watch(liveFeedStatusProvider).value ?? LiveFeedStatus.unconfigured;

    return PhantomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('This device', style: Theme.of(context).textTheme.titleMedium)),
              StatusBadge(
                label: bound ? 'Bound' : 'Not bound',
                color: bound ? AppColors.success : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            deviceId == null
                ? 'Device identifier not generated yet.'
                : 'Identifier ${deviceId.substring(0, 8)}… — the backend stores only its hash.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Bridge SIGNALS key: ${signalsKey ? 'stored' : 'not activated'} · '
            'live feed ${feedStatus.name}',
            style: AppTypography.mono(fontSize: 12, color: AppColors.mutedText),
          ),
          const SizedBox(height: AppSpacing.md),
          PhantomButton(
            label: signalsKey ? 'Forget this key' : 'Activate licence',
            variant: PhantomButtonVariant.secondary,
            onPressed: () {
              if (signalsKey) {
                forgetBridgeSignalsKey(ref);
              } else {
                showActivateLicenceSheet(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
