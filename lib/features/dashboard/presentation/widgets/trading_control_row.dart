import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/app_exceptions.dart';
import '../../../../core/permissions/permission_set.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/phantom_button.dart';
import '../../../trading_control/data/trading_control_service.dart';
import '../../../trading_control/presentation/trading_control_providers.dart';
import '../../../trading_status/presentation/trading_status_providers.dart';

/// Pause/resume on the dashboard.
///
/// Three independent gates, in the order they matter:
/// 1. the build must opt in (`TRADING_CONTROLS_ENABLED`),
/// 2. the account must hold `ea.control` (or be OWNER) — a UX gate only,
/// 3. the backend authorizes the command itself, so an unauthorized caller
///    gets 403 no matter what this widget shows.
/// The consequential action is confirmed before it is sent, and the resulting
/// state is re-read from the daemon rather than assumed from the call.
class TradingControlRow extends ConsumerWidget {
  const TradingControlRow({required this.isOwner, required this.permissions, super.key});

  final bool isOwner;
  final PermissionSet permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!tradingControlOffered(isOwner, permissions)) {
      return Text(
        'Trading controls are not available for this account.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
      );
    }

    final paused = ref.watch(tradingStateProvider).value;
    final target = ref.watch(tradingControlTargetProvider).value;
    final isPaused = paused ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          paused == null
              ? 'Trading state unknown — the bridge is not reachable.'
              : (isPaused ? 'Trading is paused on the daemon.' : 'Trading is running on the daemon.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        PhantomButton(
          label: isPaused ? 'Resume trading' : 'Pause trading',
          variant: PhantomButtonVariant.secondary,
          // No account to command, no button: a client with no EA account
          // cannot pause anything.
          onPressed: target == null ? null : () => _toggle(context, ref, isPaused, target),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          target == null
              ? 'This account has no EA account to control.'
              : 'The command is queued for the EA; the daemon’s own state is shown above.',
          style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
        ),
      ],
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool isPaused, String accountId) async {
    final confirmed = await showConfirmDialog(
      context,
      title: isPaused ? 'Resume trading' : 'Pause trading',
      message: isPaused
          ? 'The EA will be allowed to open new trades again.'
          : 'The EA will stop opening new trades. Open positions stay open.',
      confirmLabel: isPaused ? 'Resume' : 'Pause',
      destructive: !isPaused,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final service = ref.read(tradingControlServiceProvider);
      if (isPaused) {
        await service.resume(accountId: accountId);
      } else {
        await service.pause(accountId: accountId);
      }
      // Re-read the daemon's real state instead of assuming the command ran.
      ref.invalidate(tradingStatusProvider);
      ref.invalidate(tradingStateProvider);
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
