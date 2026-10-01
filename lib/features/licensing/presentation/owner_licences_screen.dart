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
      final generated = await ref
          .read(licensingServiceProvider)
          .generateScannerKey(deviceLimit: 1);
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
              itemBuilder: (context, index) =>
                  _LicenceCard(licence: items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _LicenceCard extends StatelessWidget {
  const _LicenceCard({required this.licence});

  final CoreLicence licence;

  Color _statusColor(String status) => switch (status) {
        'ACTIVE' => AppColors.success,
        'UNUSED' => AppColors.cyberBlue,
        'SUSPENDED' => AppColors.warning,
        'EXPIRED' => AppColors.mutedText,
        'REVOKED' => AppColors.error,
        _ => AppColors.mutedText,
      };

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}
