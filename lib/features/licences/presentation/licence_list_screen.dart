import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/licence.dart';
import '../domain/licence_enums.dart';
import 'generate_licence_sheet.dart';
import 'licences_providers.dart';

class LicenceListScreen extends ConsumerWidget {
  const LicenceListScreen({super.key});

  Color _statusColor(LicenceStatus s) => switch (s) {
        LicenceStatus.active => AppColors.success,
        LicenceStatus.expired => AppColors.mutedText,
        LicenceStatus.revoked => AppColors.error,
        LicenceStatus.suspended => AppColors.warning,
        LicenceStatus.unactivated => AppColors.cyberBlue,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licencesAsync = ref.watch(licenceListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Licences')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showGenerateLicenceSheet(context),
        label: const Text('Generate'),
        icon: const Icon(Icons.add),
      ),
      body: licencesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'Could not load licences.\n$e'),
        data: (licences) {
          if (licences.isEmpty) {
            return const EmptyView(icon: Icons.vpn_key_outlined, message: 'No licences yet.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: licences.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => _LicenceCard(licence: licences[i], colorFor: _statusColor),
          );
        },
      ),
    );
  }
}

class _LicenceCard extends ConsumerWidget {
  const _LicenceCard({required this.licence, required this.colorFor});
  final Licence licence;
  final Color Function(LicenceStatus) colorFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PhantomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(licence.product, style: Theme.of(context).textTheme.titleMedium),
              ),
              StatusBadge(label: licence.status.wireValue, color: colorFor(licence.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(licence.key, style: AppTypography.mono(fontSize: 13)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Devices: ${licence.activeDevices}/${licence.maxDevices}'
            '${licence.expiresAt != null ? " · Expires ${licence.expiresAt!.toLocal().toString().split(' ').first}" : " · No expiry"}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              TextButton(
                onPressed: () => ref.read(licenceServiceProvider).renew(licence.id, LicenceDuration.thirtyDays),
                child: const Text('Renew 30d'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => ref.read(licenceServiceProvider).suspend(licence.id),
                child: const Text('Suspend'),
              ),
              TextButton(
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Revoke licence',
                    message: 'Revoke ${licence.key}? This cannot be undone from the client side.',
                    confirmLabel: 'Revoke',
                  );
                  if (confirmed) await ref.read(licenceServiceProvider).revoke(licence.id);
                },
                child: const Text('Revoke', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
