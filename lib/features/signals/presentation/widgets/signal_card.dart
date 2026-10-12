import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/brand_assets.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/signal.dart';
import '../../domain/signal_enums.dart';

/// Reusable branded signal card. Same visual language is intended to be
/// reused for shareable/exported images (WhatsApp/Telegram/website) later —
/// see docs/ARCHITECTURE.md "Signal Branding". No image export in Phase 1.
class SignalCard extends StatelessWidget {
  const SignalCard({
    required this.signal,
    this.showWatermark = false,
    super.key,
  });

  final Signal signal;
  final bool showWatermark;

  Color _statusColor(SignalStatus s) => switch (s) {
        SignalStatus.pending => AppColors.warning,
        SignalStatus.approved => AppColors.cyberBlue,
        SignalStatus.published => AppColors.electricBlue,
        SignalStatus.active => AppColors.success,
        SignalStatus.tp1Hit ||
        SignalStatus.tp2Hit ||
        SignalStatus.tp3Hit =>
          AppColors.success,
        SignalStatus.stopped => AppColors.error,
        SignalStatus.cancelled => AppColors.offline,
        SignalStatus.closed => AppColors.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final isUpdate = signal.status.isClosed ||
        signal.status == SignalStatus.tp1Hit ||
        signal.status == SignalStatus.tp2Hit ||
        signal.status == SignalStatus.tp3Hit;
    final isBuy = signal.direction == SetupDirection.buy;
    return PhantomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUpdate ? 'CPT Market Update' : 'CPT Market Direction',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                signal.symbol,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: isBuy ? 'BUY' : 'SELL',
                color: isBuy ? AppColors.buy : AppColors.sell,
              ),
              const Spacer(),
              StatusBadge(
                label: _statusLabel(signal.status),
                color: _statusColor(signal.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Wraps on narrow phones instead of overflowing.
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _metric(context, 'Entry', signal.entry),
              _metric(context, 'SL', signal.stopLoss, color: AppColors.error),
              if (signal.takeProfits.isNotEmpty)
                _metric(
                  context,
                  'TP',
                  signal.takeProfits.first,
                  color: AppColors.success,
                ),
              if (signal.takeProfits.length > 1)
                _metric(
                  context,
                  'TP2',
                  signal.takeProfits[1],
                  color: AppColors.success,
                ),
            ],
          ),
          if (signal.rMultiple != null &&
              signal.status.isClosed &&
              signal.status != SignalStatus.cancelled &&
              ['WIN', 'LOSS', 'BREAKEVEN'].contains(signal.result)) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Observed signal result: ${signal.rMultiple!.toStringAsFixed(2)}R',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${signal.timeframe == null ? '' : '${signal.timeframe} · '}${signal.openedAt.toUtc().toIso8601String()} UTC',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (signal.closedAt != null)
            Text('Updated: ${signal.closedAt!.toUtc().toIso8601String()}'),
          const Text('Signal observation · Broker execution is not confirmed.'),
          if (showWatermark) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              BrandAssets.tradingBrand,
              style:
                  AppTypography.mono(fontSize: 10, color: AppColors.mutedText),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(SignalStatus status) => switch (status) {
        SignalStatus.pending => 'Awaiting review',
        SignalStatus.approved => 'Approved draft',
        SignalStatus.published => 'Published suggestion',
        SignalStatus.active => 'Active suggestion',
        SignalStatus.tp1Hit => 'TP reached',
        SignalStatus.tp2Hit => 'TP2 reached',
        SignalStatus.tp3Hit => 'Target reached',
        SignalStatus.stopped => 'SL reached',
        SignalStatus.cancelled => 'Cancelled',
        SignalStatus.closed =>
          ['WIN', 'LOSS', 'BREAKEVEN'].contains(signal.result)
              ? 'Closed observation'
              : 'Outcome unresolved',
      };

  Widget _metric(
    BuildContext context,
    String label,
    double value, {
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value.toStringAsFixed(5),
          style: AppTypography.mono(color: color ?? AppColors.ghostWhite),
        ),
      ],
    );
  }
}
