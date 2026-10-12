import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_assets.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/scanner_enums.dart';
import 'scanner_providers.dart';
import 'widgets/setup_card.dart';

/// Pending / Approved / Rejected / History tabs for reviewers; a plain
/// "Approved" tab for everyone else.
///
/// Normal clients (no `Permission.scannerReview`) never see the review
/// actions on the detail screen — see `setup_detail_screen.dart`'s
/// `PermissionGate` — and their tab set has no Pending/Rejected/History,
/// so there's nothing in the nav to even lead them to that data. The
/// underlying providers enforce the same rule independently (see
/// `scanner_providers.dart`), so this is UX, not the only safeguard.
class ScannerScreen extends ConsumerWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReview = ref.watch(hasPermissionProvider(Permission.scannerReview));
    final tabs = canReview
        ? const ['Pending', 'Approved', 'Rejected', 'History']
        : const ['Approved'];

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
            if (canReview) const _SetupList(status: null), // History = all statuses
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
    final showDiagnostics = ref.watch(hasPermissionProvider(Permission.scannerReview));

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
              showDiagnostics: showDiagnostics,
              setup: setup,
              onTap: () => context.push('/scanner/setup/${setup.id}'),
            );
          },
        );
      },
    );
  }
}
