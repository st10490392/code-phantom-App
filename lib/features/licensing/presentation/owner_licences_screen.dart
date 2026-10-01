import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/licensing_models.dart';
import 'licensing_providers.dart';

class OwnerLicencesScreen extends ConsumerStatefulWidget {
  const OwnerLicencesScreen({super.key});

  @override
  ConsumerState<OwnerLicencesScreen> createState() =>
      _OwnerLicencesScreenState();
}

class _OwnerLicencesScreenState extends ConsumerState<OwnerLicencesScreen> {
  bool _generating = false;

  Future<void> _generateKey() async {
    setState(() => _generating = true);
    try {
      final service = ref.read(licensingServiceProvider);
      if (service == null) {
        throw StateError('Licensing is unavailable in this build.');
      }
      final generated = await service.generateScannerKey(deviceLimit: 1);
      ref.invalidate(ownerLicencesProvider);
      if (!mounted) return;
      await _showGeneratedKey(generated);
    } catch (error) {
      if (!mounted) return;
      final message = error is AppException
          ? error.message
          : 'Could not generate an activation key.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _showGeneratedKey(GeneratedActivationKey generated) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Scanner key generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Copy this key now. For security, CodePhantom stores only its hash and cannot show the full key again.',
            ),
            const SizedBox(height: AppSpacing.lg),
            SelectableText(
              generated.activationKey,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'JetBrains Mono',
                    color: AppColors.cyberBlue,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: generated.activationKey),
                );
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Activation key copied.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy key'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Plan: CPT Scanner Access · 1 device',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('I saved the key'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final licences = ref.watch(ownerLicencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activation Keys')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generating ? null : _generateKey,
        icon: const Icon(Icons.add),
        label: Text(_generating ? 'Generating…' : 'Generate Scanner key'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ownerLicencesProvider);
          await ref.read(ownerLicencesProvider.future);
        },
        child: licences.when(
          loading: () => const LoadingView(),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              ErrorView(message: 'Could not load activation keys.\n$error'),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [
                  EmptyView(
                    icon: Icons.vpn_key_outlined,
                    message: 'No activation keys yet. Generate one when you want to grant Scanner access.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                96,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _LicenceCard(
                licence: items[index],
                onChanged: () => ref.invalidate(ownerLicencesProvider),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LicenceCard extends ConsumerWidget {
  const _LicenceCard({
    required this.licence,
    required this.onChanged,
  });

  final CoreLicence licence;
  final VoidCallback onChanged;

  Future<void> _issueReplacementKey(BuildContext context, WidgetRef ref) async {
    final userId = licence.userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This activation key has not been redeemed yet.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final verificationController = TextEditingController();
    final verification = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Issue replacement device key?'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Only issue this after verifying the account holder. Redeeming it will revoke the old device binding.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: verificationController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Identity verification note',
                  hintText: 'How did you verify the account holder?',
                ),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Record how identity was verified.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.of(dialogContext).pop(verificationController.text.trim());
            },
            child: const Text('Issue key'),
          ),
        ],
      ),
    );
    verificationController.dispose();
    if (verification == null) return;

    try {
      final service = ref.read(licensingServiceProvider);
      if (service == null) {
        throw StateError('Licensing is unavailable in this build.');
      }
      final generated = await service.generateDeviceBindingKey(
        userId: userId,
        identityVerification: verification,
      );
      if (!context.mounted) return;
      await _showReplacementKey(context, generated);
    } catch (error) {
      if (!context.mounted) return;
      final message = error is AppException
          ? error.message
          : 'Could not issue a replacement device key.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _showReplacementKey(
    BuildContext context,
    GeneratedDeviceBindingKey generated,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replacement device key generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Copy this key now. It is shown once and expires automatically.',
            ),
            const SizedBox(height: AppSpacing.lg),
            SelectableText(
              generated.bindingKey,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'JetBrains Mono',
                    color: AppColors.cyberBlue,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: generated.bindingKey));
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Replacement key copied.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy replacement key'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Expires ${generated.expiresAt.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('I saved the key'),
          ),
        ],
      ),
    );
  }
  Color _statusColor(String status) => switch (status) {
        'ACTIVE' => AppColors.success,
        'UNUSED' => AppColors.cyberBlue,
        'SUSPENDED' => AppColors.warning,
        'EXPIRED' => AppColors.mutedText,
        'REVOKED' => AppColors.error,
        _ => AppColors.mutedText,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PhantomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  licence.planCode == 'scanner_v1'
                      ? 'CPT Scanner Access'
                      : licence.planCode,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusBadge(
                label: licence.status,
                color: _statusColor(licence.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Key prefix: ${licence.keyPrefix}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'JetBrains Mono',
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Devices: ${licence.deviceLimit} · Created ${licence.createdAt.toLocal().toString().split(' ').first}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (licence.redeemedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Redeemed ${licence.redeemedAt!.toLocal().toString().split(' ').first}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (licence.status != 'REVOKED') ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (licence.status == 'ACTIVE' && licence.userId != null)
                  OutlinedButton.icon(
                    onPressed: () => _issueReplacementKey(context, ref),
                    icon: const Icon(Icons.phonelink_lock_outlined),
                    label: const Text('Replacement key'),
                  ),
                if (licence.status == 'ACTIVE')
                  OutlinedButton(
                    onPressed: () async {
                      await ref
                          .read(licensingServiceProvider)
                          ?.suspendLicence(licence.id);
                      onChanged();
                    },
                    child: const Text('Suspend'),
                  ),
                if (licence.status == 'SUSPENDED')
                  OutlinedButton(
                    onPressed: () async {
                      await ref
                          .read(licensingServiceProvider)
                          ?.reinstateLicence(licence.id);
                      onChanged();
                    },
                    child: const Text('Reinstate'),
                  ),
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Revoke activation key?'),
                            content: Text(
                              licence.status == 'UNUSED'
                                  ? 'This unused key will never be redeemable after revocation.'
                                  : 'This licence and its bound devices will lose access. Revocation is permanent.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: const Text(
                                  'Revoke',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ) ??
                        false;
                    if (!confirmed) return;
                    await ref
                        .read(licensingServiceProvider)
                        ?.revokeLicence(licence.id);
                    onChanged();
                  },
                  child: const Text(
                    'Revoke',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
