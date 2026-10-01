import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/app_role.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_assets.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../ea/presentation/ea_providers.dart';
import '../../ea/domain/ea_enums.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../../licensing/presentation/client_activation_view.dart';
import '../../scanner/domain/scanner_enums.dart';
import '../../scanner/presentation/scanner_providers.dart';
import '../../signals/presentation/signals_providers.dart';

/// Dashboard aggregates read-only summaries from every module's own
/// providers/repositories — it never talks to a service directly. This is
/// what keeps a real backend swap (Phase 2+) invisible to this screen.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    // A CLIENT only sees onboarding while it truly has no paid/granted
    // service access. Server-authoritative entitlements and grants are
    // translated into these UI permissions by the backend profile mapping.
    final hasAnyClientService = user?.permissions.hasAny(const [
          Permission.scannerAccess,
          Permission.signalsAccess,
          Permission.eaAccess,
        ]) ??
        false;
    if (user?.role == AppRole.client && !hasAnyClientService) {
      return const ClientActivationView();
    }

    final hasScannerAccess = ref.watch(hasPermissionProvider(Permission.scannerAccess));
    final hasSignalsAccess = ref.watch(hasPermissionProvider(Permission.signalsAccess));
    final hasEaAccess = ref.watch(hasPermissionProvider(Permission.eaAccess));

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Header(name: user?.displayName ?? 'there'),
          const SizedBox(height: AppSpacing.xl),
          if (hasScannerAccess) ...[
            Text('Scanner', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            const _ScannerSummary(),
            const SizedBox(height: AppSpacing.xl),
          ],
          if (hasSignalsAccess) ...[
            Text('Signals', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            const _SignalsSummary(),
            const SizedBox(height: AppSpacing.xl),
          ],
          if (hasEaAccess) ...[
            Text('EA', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            const _EASummary(),
            const SizedBox(height: AppSpacing.xl),
          ],
          Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const _NotificationsSummary(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back', style: Theme.of(context).textTheme.bodySmall),
              Text(name, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              BrandAssets.appName.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    letterSpacing: 2,
                    color: AppColors.mutedText,
                  ),
            ),
            Text(
              BrandAssets.tagline,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(children: [for (final t in tiles) Expanded(child: t)]);
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: PhantomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ScannerSummary extends ConsumerWidget {
  const _ScannerSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allSetupsProvider);
    return all.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: '$e'),
      data: (setups) => _SummaryRow(tiles: [
        _SummaryTile(
          label: 'Pending',
          value: '${setups.where((s) => s.status == SetupStatus.pending).length}',
          color: AppColors.warning,
        ),
        _SummaryTile(
          label: 'Approved',
          value: '${setups.where((s) => s.status == SetupStatus.approved).length}',
          color: AppColors.success,
        ),
        _SummaryTile(
          label: 'Rejected',
          value: '${setups.where((s) => s.status == SetupStatus.rejected).length}',
          color: AppColors.error,
        ),
      ],),
    );
  }
}

class _SignalsSummary extends ConsumerWidget {
  const _SignalsSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSignalsProvider);
    final closed = ref.watch(closedSignalsProvider);
    final performance = ref.watch(signalPerformanceProvider);

    if (active.isLoading || closed.isLoading || performance.isLoading) {
      return const LoadingView();
    }

    return _SummaryRow(tiles: [
      _SummaryTile(label: 'Active', value: '${active.valueOrNull?.length ?? 0}', color: AppColors.success),
      _SummaryTile(label: 'Closed', value: '${closed.valueOrNull?.length ?? 0}'),
      _SummaryTile(
        label: 'Win rate',
        value: '${performance.valueOrNull?.winRatePercent.toStringAsFixed(0) ?? '–'}%',
        color: AppColors.electricBlue,
      ),
    ],);
  }
}

class _EASummary extends ConsumerWidget {
  const _EASummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(primaryEAAccountProvider);
    return accountAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: '$e'),
      data: (account) => account == null
          ? const EmptyView(icon: Icons.monitor_heart_outlined,
              message: 'No EA account connected yet.',)
          : account.lastHeartbeat.millisecondsSinceEpoch == 0
              ? const PhantomCard(child: Text('Waiting for the first EA heartbeat.'))
              : _SummaryRow(tiles: [
        _SummaryTile(
          label: 'Status',
          value: account.status.wireValue,
          color: account.status == EAConnectionStatus.online ? AppColors.online : AppColors.offline,
        ),
        _SummaryTile(
          label: 'Daily P/L',
          value: '\$${account.dailyProfit.toStringAsFixed(0)}',
          color: account.dailyProfit >= 0 ? AppColors.success : AppColors.error,
        ),
        _SummaryTile(label: 'Drawdown', value: '${account.dailyDrawdown.toStringAsFixed(1)}%'),
      ],),
    );
  }
}

class _NotificationsSummary extends ConsumerWidget {
  const _NotificationsSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationListProvider);
    return notificationsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: '$e'),
      data: (notifications) {
        final recent = [...notifications]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return Column(
          children: [
            for (final n in recent.take(3))
              PhantomCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(child: Text(n.title, overflow: TextOverflow.ellipsis)),
                    Text(
                      _relativeTime(n.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
