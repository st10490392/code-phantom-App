import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/permissions/permission_gate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/scanner_setup.dart';
import 'scanner_providers.dart';

/// Setup detail + APPROVE/REJECT/EDIT actions.
///
/// Per the brief: normal clients only ever see approved/published signals —
/// this sheet (and the Pending tab it's opened from) is gated by
/// `Permission.scannerReview`, granted only to OWNER/ADMIN by default.
Future<void> showSetupDetailSheet(BuildContext context, ScannerSetup setup) {
  return showPhantomModalSheet(
    context: context,
    title: '${setup.symbol} · ${setup.timeframe}',
    builder: (context) => _SetupDetailBody(setup: setup),
  );
}

class _SetupDetailBody extends ConsumerWidget {
  const _SetupDetailBody({required this.setup});
  final ScannerSetup setup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(context, 'Direction', setup.direction.wireValue),
        _row(context, 'Entry', setup.entry.toStringAsFixed(5)),
        _row(context, 'Stop loss', setup.stopLoss.toStringAsFixed(5)),
        if (setup.tp1 != null) _row(context, 'TP1', setup.tp1!.toStringAsFixed(5)),
        if (setup.tp2 != null) _row(context, 'TP2', setup.tp2!.toStringAsFixed(5)),
        if (setup.tp3 != null) _row(context, 'TP3', setup.tp3!.toStringAsFixed(5)),
        _row(context, 'Weekly bias', setup.weeklyBias.wireValue),
        _row(context, 'Daily bias', setup.dailyBias.wireValue),
        _row(context, 'Session', setup.session.wireValue),
        _row(context, 'Confluence', '${setup.confluenceScore}/${setup.confluenceMaximum}'),
        _row(context, 'Status', setup.status.wireValue),
        if (setup.notes != null) _row(context, 'Notes', setup.notes!),
        const SizedBox(height: AppSpacing.lg),
        PermissionGate(
          permission: Permission.scannerReview,
          child: Row(
            children: [
              Expanded(
                child: PhantomButton(
                  label: 'Reject',
                  variant: PhantomButtonVariant.secondary,
                  onPressed: () async {
                    final reason = await _promptReason(context);
                    if (reason == null) return;
                    await ref.read(scannerServiceProvider).reject(setup.id, reason: reason);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PhantomButton(
                  label: 'Approve',
                  onPressed: () async {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Approve setup',
                      message: 'Approve ${setup.symbol} ${setup.direction.wireValue}? '
                          'This makes it eligible for publishing as a signal.',
                      confirmLabel: 'Approve',
                      destructive: false,
                    );
                    if (!confirmed) return;
                    await ref.read(scannerServiceProvider).approve(setup.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.mutedText)),
          Text(value),
        ],
      ),
    );
  }

  Future<String?> _promptReason(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject setup'),
        content: PhantomTextField(label: 'Reason', controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          PhantomButton(
            label: 'Reject',
            variant: PhantomButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(
              controller.text.isEmpty ? 'No reason provided' : controller.text,
            ),
          ),
        ],
      ),
    );
  }
}
