import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/ea_account.dart';
import '../domain/ea_enums.dart';
import 'ea_providers.dart';

/// OWNER controls: pause/resume, change risk mode/%, disable new entries,
/// emergency stop. Screen calling this must gate visibility behind
/// `Permission.eaControl` (see `ea_dashboard_screen.dart`).
Future<void> showRiskControlsSheet(BuildContext context, EAAccount account) {
  return showPhantomModalSheet(
    context: context,
    title: 'Controls · ${account.nickname}',
    builder: (context) => _RiskControlsBody(account: account),
  );
}

class _RiskControlsBody extends ConsumerWidget {
  const _RiskControlsBody({required this.account});
  final EAAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final control = ref.read(eaControlServiceProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: PhantomButton(
                label: account.tradingEnabled ? 'Pause trading' : 'Resume trading',
                variant: PhantomButtonVariant.secondary,
                onPressed: () async {
                  if (account.tradingEnabled) {
                    await control.pauseTrading(account.accountId);
                  } else {
                    await control.resumeTrading(account.accountId);
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Risk mode', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final mode in RiskMode.values)
              PhantomChip(
                label: mode.wireValue.replaceAll('_', ' '),
                selected: account.riskMode == mode,
                onTap: () async {
                  await control.setRiskMode(account.accountId, mode);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        PhantomButton(
          label: 'Set risk % · current \${account.riskPercentage.toStringAsFixed(2)}%',
          variant: PhantomButtonVariant.secondary,
          onPressed: () async {
            final controller = TextEditingController(text: account.riskPercentage.toString());
            final selected = await showDialog<double>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Custom risk per trade'),
                content: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Risk %',
                    helperText: 'Allowed range: 0.01% to 100%',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      final value = double.tryParse(controller.text.trim());
                      if (value == null || value < 0.01 || value > 100) return;
                      Navigator.of(dialogContext).pop(value);
                    },
                    child: const Text('Continue'),
                  ),
                ],
              ),
            );
            controller.dispose();
            if (selected == null || !context.mounted) return;

            if (selected > 5) {
              final warning = selected >= 50
                  ? 'This setting is extremely aggressive. A single stopped trade can remove most or all usable account equity within seconds or minutes.'
                  : 'This risk setting is highly aggressive. Losses can accumulate very quickly.';
              final confirmed = await showConfirmDialog(
                context,
                title: 'Extreme risk warning',
                message: '$warning\n\nSelected risk: \${selected.toStringAsFixed(2)}% per trade.',
                confirmLabel: 'I understand the risk',
              );
              if (!confirmed) return;
            }

            await control.setRiskPercentage(account.accountId, selected);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        PhantomButton(
          label: 'Disable new entries',
          variant: PhantomButtonVariant.secondary,
          onPressed: () async {
            await control.disableNewEntries(account.accountId);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        PhantomButton(
          label: 'Emergency stop',
          variant: PhantomButtonVariant.secondary,
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: 'Emergency stop',
              message:
                  'This immediately disables trading and marks ${account.nickname} offline. '
                  'Use only in an emergency.',
              confirmLabel: 'Emergency stop',
            );
            if (!confirmed) return;
            await control.emergencyStop(account.accountId);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
