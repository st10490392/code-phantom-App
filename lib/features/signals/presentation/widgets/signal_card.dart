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
  const SignalCard({required this.signal, this.showWatermark = false, super.key});

  final Signal signal;
  final bool showWatermark;

  Color _statusColor(SignalStatus s) => switch (s) {
        SignalStatus.pending => AppColors.warning,
        SignalStatus.approved => AppColors.cyberBlue,
        SignalStatus.published => AppColors.electricBlue,
        SignalStatus.active => AppColors.success,
        SignalStatus.tp1Hit || SignalStatus.tp2Hit || SignalStatus.tp3Hit => AppColors.success,
        SignalStatus.stopped => AppColors.error,
        SignalStatus.cancelled => AppColors.offline,
        SignalStatus.closed => AppColors.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final isBuy = signal.direction == SetupDirection.buy;
    return PhantomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(signal.symbol, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(label: isBuy ? 'BUY' : 'SELL', color: isBuy ? AppColors.buy : AppColors.sell),
              const Spacer(),
              StatusBadge(
                label: signal.status.wireValue.replaceAll('_', ' '),
                color: _statusColor(signal.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _metric(context, 'Entry', signal.entry),
              const SizedBox(width: AppSpacing.lg),
              _metric(context, 'SL', signal.stopLoss, color: AppColors.error),
              if (signal.takeProfits.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.lg),
                _metric(context, 'TP1', signal.takeProfits.first, color: AppColors.success),
              ],
            ],
          ),
          if (signal.rMultiple != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'R multiple: ${signal.rMultiple!.toStringAsFixed(2)}R'
              '${signal.result != null ? " · ${signal.result}" : ""}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (showWatermark) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              BrandAssets.tradingBrand,
              style: AppTypography.mono(fontSize: 10, color: AppColors.mutedText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, double value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value.toStringAsFixed(5), style: AppTypography.mono(color: color ?? AppColors.ghostWhite)),
      ],
    );
  }
}
