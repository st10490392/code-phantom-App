import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utilities/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/scanner_enums.dart';
import '../../domain/scanner_setup.dart';
import '../setup_status_style.dart';

class SetupCard extends StatelessWidget {
  const SetupCard({required this.setup, this.onTap, this.showDiagnostics = false, super.key});

  final ScannerSetup setup;
  final bool showDiagnostics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isBuy = setup.direction == SetupDirection.buy;
    final directionColor = isBuy ? AppColors.buy : AppColors.sell;

    return PhantomCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(setup.symbol, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: isBuy ? 'BUY' : 'SELL',
                color: directionColor,
              ),
              const Spacer(),
              Text(setup.timeframe, style: AppTypography.mono(color: AppColors.mutedText)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Wraps on narrow phones (e.g. XAUUSD/index prices on a 375pt
          // Safari viewport) instead of overflowing.
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _MetricLabel(label: 'Entry', value: setup.entry.toStringAsFixed(5)),
              _MetricLabel(label: 'SL', value: setup.stopLoss.toStringAsFixed(5), color: AppColors.error),
              if (setup.tp1 != null)
                _MetricLabel(label: 'TP1', value: setup.tp1!.toStringAsFixed(5), color: AppColors.success),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (setup.market != null) PhantomChip(label: setup.market!),
              if (showDiagnostics && setup.weeklyBias.isKnown) PhantomChip(label: 'Weekly ${setup.weeklyBias.wireValue}'),
              if (showDiagnostics && setup.dailyBias.isKnown) PhantomChip(label: 'Daily ${setup.dailyBias.wireValue}'),
              if (showDiagnostics && setup.session.isKnown) PhantomChip(label: setup.session.wireValue.replaceAll('_', ' ')),
              if (showDiagnostics && setup.confluenceMaximum > 0)
                PhantomChip(label: 'Confluence ${setup.confluenceScore}/${setup.confluenceMaximum}'),
              if (showDiagnostics && setup.strategyProfile != null) PhantomChip(label: setup.strategyProfile!),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusBadge(label: setup.status.wireValue, color: setupStatusColor(setup.status)),
              Text(
                relativeTime(setup.detectedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricLabel extends StatelessWidget {
  const _MetricLabel({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: AppTypography.mono(color: color ?? AppColors.ghostWhite)),
      ],
    );
  }
}
