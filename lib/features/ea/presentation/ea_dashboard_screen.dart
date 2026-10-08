import 'gilgamesh_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/ea_account.dart';
import '../domain/ea_enums.dart';
import 'ea_providers.dart';

/// System-control interface, not a "flashy retail trading" screen — visual
/// priority goes to status/metrics/risk, brand glow reserved for the header
/// only (see docs/ARCHITECTURE.md "EA Branding").
class EADashboardScreen extends ConsumerWidget {
  const EADashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(primaryEAAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('CPT ENKIDU EA')),
      body: accountAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'Could not load EA account.\n$e'),
        data: (account) => account == null
            ? const SingleChildScrollView(child: GilgameshPanel())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const GilgameshPanel(),
                  const SizedBox(height: AppSpacing.lg),
                  _StatusHeader(account: account),
                  const SizedBox(height: AppSpacing.lg),
                  if (account.lastHeartbeat.millisecondsSinceEpoch == 0)
                    const PhantomCard(
                      child: Text(
                        'Waiting for the EA to send its first heartbeat.',
                      ),
                    )
                  else
                    _MetricsGrid(account: account),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.account});
  final EAAccount account;

  @override
  Widget build(BuildContext context) {
    final isOnline = account.status == EAConnectionStatus.online;
    return PhantomCard(
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.online : AppColors.offline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.nickname,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  account.broker,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StatusBadge(
            label: account.status.wireValue,
            color: isOnline ? AppColors.online : AppColors.offline,
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.account});
  final EAAccount account;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Metric('Balance', '\$${account.balance.toStringAsFixed(2)}'),
      _Metric('Equity', '\$${account.equity.toStringAsFixed(2)}'),
      _Metric(
        'Daily P/L',
        '${account.dailyProfit >= 0 ? '+' : ''}\$${account.dailyProfit.toStringAsFixed(2)}',
        color: account.dailyProfit >= 0 ? AppColors.success : AppColors.error,
      ),
      _Metric('Daily drawdown', '${account.dailyDrawdown.toStringAsFixed(2)}%'),
      _Metric('Open trades', '${account.openTrades}'),
      _Metric('Risk mode', account.riskMode.wireValue.replaceAll('_', ' ')),
      _Metric('Risk %', '${account.riskPercentage.toStringAsFixed(2)}%'),
      _Metric(
        'Trading',
        account.tradingEnabled ? 'ENABLED' : 'DISABLED',
        color: account.tradingEnabled ? AppColors.success : AppColors.mutedText,
      ),
    ];

    // Fixed tile height (not an aspect ratio) so tiles never clip on
    // narrow phones; wider windows simply fit more columns.
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 108,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      children: [for (final t in tiles) _MetricTile(metric: t)],
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return PhantomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(metric.label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          // One line at any width: long balances shrink rather than wrap.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              metric.value,
              maxLines: 1,
              style: AppTypography.mono(
                fontSize: 16,
                color: metric.color ?? AppColors.ghostWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
