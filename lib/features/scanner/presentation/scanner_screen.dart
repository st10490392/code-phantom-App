import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_assets.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/scanner_enums.dart';
import 'scanner_providers.dart';
import 'setup_detail_sheet.dart';
import 'widgets/setup_card.dart';

/// Pending / Approved / Rejected / History tabs, per brief.
///
/// Normal clients (no `Permission.scannerReview`) never see the Pending
/// tab's approve/reject controls — see `setup_detail_sheet.dart`'s
/// `PermissionGate`. Clients without explicit grant to view pending items
/// still only load approved data through `setupsByStatusProvider`.
class ScannerScreen extends ConsumerWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReview = ref.watch(hasPermissionProvider(Permission.scannerReview));
    final tabs = canReview
        ? const ['Pending', 'Approved', 'Rejected', 'History']
        : const ['Approved', 'History'];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Scanner'),
              Text(
                BrandAssets.scannerBrandLine,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.mutedText),
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final t in tabs) Tab(text: t)],
          ),
        ),
        body: TabBarView(
          children: [
            if (canReview) const _SetupList(status: SetupStatus.pending),
            const _SetupList(status: SetupStatus.approved),
            if (canReview) const _SetupList(status: SetupStatus.rejected),
            const _SetupList(status: null), // History = all statuses
          ],
        ),
      ),
    );
  }
}

class _SetupList extends ConsumerWidget {
  const _SetupList({required this.status});
  final SetupStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupsAsync = ref.watch(setupsByStatusProvider(status));

    return setupsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Could not load setups.\n$e'),
      data: (setups) {
        if (setups.isEmpty) {
          return const EmptyView(
            icon: Icons.radar_outlined,
            message: 'No setups here yet.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: setups.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            final setup = setups[i];
            return SetupCard(
              setup: setup,
              onTap: () => showSetupDetailSheet(context, setup),
            );
          },
        );
      },
    );
  }
}
