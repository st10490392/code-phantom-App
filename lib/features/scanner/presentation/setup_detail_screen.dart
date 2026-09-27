import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/permissions/permission_gate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utilities/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/scanner_enums.dart';
import '../domain/scanner_setup.dart';
import 'edit_setup_sheet.dart';
import 'reject_reason_sheet.dart';
import 'scanner_providers.dart';
import 'setup_status_style.dart';

/// Full-screen setup detail, reached via `/scanner/setup/:id`.
///
/// `setupByIdProvider` already enforces visibility (a non-reviewer can
/// never resolve a pending/rejected setup's id — see
/// `scanner_providers.dart`), so this screen only has to render whatever
/// it's handed: found-and-visible, or not.
class SetupDetailScreen extends ConsumerWidget {
  const SetupDetailScreen({required this.setupId, super.key});
  final String setupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupAsync = ref.watch(setupByIdProvider(setupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Setup detail')),
      body: setupAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'Could not load this setup.\n$e'),
        data: (setup) => setup == null
            ? const UnauthorizedView(
                message: "This setup isn't available.",
              )
            : SetupDetailBody(setup: setup),
      ),
    );
  }
}

class SetupDetailBody extends ConsumerWidget {
  const SetupDetailBody({required this.setup, super.key});
  final ScannerSetup setup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBuy = setup.direction == SetupDirection.buy;
    final reviewState = ref.watch(scannerReviewControllerProvider);
    final isPending = setup.status == SetupStatus.pending;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Text(
              '${setup.symbol} · ${setup.timeframe}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge(label: isBuy ? 'BUY' : 'SELL', color: isBuy ? AppColors.buy : AppColors.sell),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        StatusBadge(label: setup.status.wireValue, color: setupStatusColor(setup.status)),
        if (setup.editedBeforeApproval) ...[
          const SizedBox(height: AppSpacing.sm),
          const StatusBadge(label: 'EDITED BEFORE APPROVAL', color: AppColors.warning),
        ],
        const SizedBox(height: AppSpacing.xl),
        _row(context, 'Entry', setup.entry.toStringAsFixed(5)),
        _row(context, 'Stop loss', setup.stopLoss.toStringAsFixed(5)),
        if (setup.tp1 != null) _row(context, 'TP1', setup.tp1!.toStringAsFixed(5)),
        if (setup.tp2 != null) _row(context, 'TP2', setup.tp2!.toStringAsFixed(5)),
        if (setup.tp3 != null) _row(context, 'TP3', setup.tp3!.toStringAsFixed(5)),
        if (setup.market != null) _row(context, 'Market', setup.market!),
        if (setup.brokerSymbol != null) _row(context, 'Broker symbol', setup.brokerSymbol!),
        if (setup.weeklyBias.isKnown) _row(context, 'Weekly bias', setup.weeklyBias.wireValue),
        if (setup.dailyBias.isKnown) _row(context, 'Daily bias', setup.dailyBias.wireValue),
        if (setup.session.isKnown) _row(context, 'Session', setup.session.wireValue.replaceAll('_', ' ')),
        if (setup.confluenceMaximum > 0)
          _row(context, 'Confluence', '${setup.confluenceScore}/${setup.confluenceMaximum}'),
        _row(context, 'Detected', '${utcTimestamp(setup.detectedAt)} (${relativeTime(setup.detectedAt)})'),
        if (setup.strategyProfile != null) _row(context, 'Strategy', setup.strategyProfile!),
        if (setup.externalId != null) _row(context, 'Scanner ID', setup.externalId!),
        if (setup.notes != null) _row(context, 'Notes', setup.notes!),
        if (setup.rejectionReason != null) _row(context, 'Rejection reason', setup.rejectionReason!),
        if (setup.reviewedBy != null) _row(context, 'Reviewed by', setup.reviewedBy!),
        if (setup.reviewedAt != null) _row(context, 'Reviewed', relativeTime(setup.reviewedAt!)),
        const SizedBox(height: AppSpacing.xl),
        if (isPending && ref.watch(scannerReviewActionsEnabledProvider))
          PermissionGate(
            permission: Permission.scannerReview,
            child: Column(
              children: [
                PhantomButton(
                  label: 'Edit',
                  variant: PhantomButtonVariant.ghost,
                  expand: true,
                  onPressed: () => showEditSetupSheet(context, setup),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: PhantomButton(
                        label: 'Reject',
                        variant: PhantomButtonVariant.secondary,
                        isLoading: reviewState.isLoading,
                        onPressed: () => _handleReject(context, ref),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PhantomButton(
                        label: 'Approve',
                        isLoading: reviewState.isLoading,
                        onPressed: () => _handleApprove(context, ref),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleApprove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Approve setup',
      message: 'Approve ${setup.symbol} ${setup.direction.wireValue}? '
          'This creates a signal in the Signals module.',
      confirmLabel: 'Approve',
      destructive: false,
    );
    if (!confirmed) return;

    try {
      await ref.read(scannerReviewControllerProvider.notifier).approve(setup.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${setup.symbol} approved and published to Signals.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not approve: $e')),
        );
      }
    }
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    final reason = await showRejectReasonSheet(context);
    if (reason == null) return;

    try {
      await ref.read(scannerReviewControllerProvider.notifier).reject(setup.id, reason: reason);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${setup.symbol} rejected.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reject: $e')),
        );
      }
    }
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.mutedText)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(value, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
