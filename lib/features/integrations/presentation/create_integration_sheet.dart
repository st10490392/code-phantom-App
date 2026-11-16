import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import 'integrations_providers.dart';
import '../domain/integration.dart';

/// Shows a bottom sheet for creating a new SCANNER_PUBLISHER integration.
Future<void> showCreateIntegrationSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CreateIntegrationSheet(),
  );
}

/// Shows the newly created secret **once** in a secure modal with copy action.
/// The secret is never logged or persisted by the client.
Future<void> showSecretModal(BuildContext context, String secret, String integrationName) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.phantomBlack.withValues(alpha: 0.85),
    builder: (_) => _SecretModal(secret: secret, integrationName: integrationName),
  );
}

class _CreateIntegrationSheet extends ConsumerStatefulWidget {
  const _CreateIntegrationSheet();

  @override
  ConsumerState<_CreateIntegrationSheet> createState() => _CreateIntegrationSheetState();
}

class _CreateIntegrationSheetState extends ConsumerState<_CreateIntegrationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Create Integration', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _busy ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Creates a new SCANNER_PUBLISHER integration with the `scanner.publish` scope. '
              'The secret is shown only once — copy and store it securely.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: AppSpacing.lg),
            PhantomTextField(
              controller: _nameController,
              label: 'Integration name',
              hint: 'e.g., Production Scanner',
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            PhantomButton(
              label: 'Create integration',
              onPressed: _busy ? null : _submit,
              loading: _busy,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final integration = await ref
          .read(integrationControllerProvider.notifier)
          .createScannerPublisher(name: _nameController.text.trim());
      if (!context.mounted) return;
      Navigator.pop(context);
      if (integration.plaintextSecret != null) {
        await showSecretModal(context, integration.plaintextSecret!, integration.name);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create integration: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
class _SecretModal extends StatelessWidget {
  const _SecretModal({required this.secret, required this.integrationName});
  final String secret;
  final String integrationName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Integration Secret', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.phantomBlack,
              borderRadius: BorderRadius.circular(AppSpacing.md),
              border: Border.all(color: AppColors.termLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secret for "$integrationName"',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  secret,
                  style: AppTypography.mono(fontSize: 14, color: AppColors.ghostWhite),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warn.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.md),
              border: Border.all(color: AppColors.warn.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warn, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'This secret is shown only once. Copy it now and store it securely. '
                    'It cannot be retrieved again.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warn),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: PhantomButton.outline(
                  label: 'Done',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PhantomButton(
                  label: 'Copy secret',
                  icon: Icons.copy,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: secret));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Secret copied to clipboard')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}