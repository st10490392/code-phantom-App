import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/permissions/permission.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/integration.dart'
    show Integration, IntegrationType, IntegrationStatus;
import 'integrations_providers.dart';
import 'create_integration_sheet.dart';

class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final integrationsAsync = ref.watch(integrationsProvider);
    final canManage = ref.watch(hasPermissionProvider(Permission.integrationsManage));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Integrations'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Create integration',
              onPressed: () => showCreateIntegrationSheet(context),
            ),
        ],
      ),
      body: integrationsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'Could not load integrations.\n$e'),
        data: (integrations) {
          if (integrations.isEmpty) {
            return const EmptyView(
              icon: Icons.integration_instructions_outlined,
              message: 'No integrations yet.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: integrations.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => _IntegrationCard(integration: integrations[i]),
          );
        },
      ),
    );
  }
}

class _IntegrationCard extends ConsumerWidget {
  const _IntegrationCard({required this.integration});
  final Integration integration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(hasPermissionProvider(Permission.integrationsManage));

    return PhantomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      integration.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      integration.type.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedText,
                          ),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: integration.status.label, color: _statusColor(integration.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            'ID: ${integration.id}',
            style: AppTypography.mono(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Scopes: ${integration.scopes.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Created: ${_formatDate(integration.createdAt)}'
            '${integration.lastUsedAt != null ? ' · Last used: ${_formatDate(integration.lastUsedAt!)}' : ''}'
            '${integration.revokedAt != null ? ' · Revoked: ${_formatDate(integration.revokedAt!)}' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
          if (canManage && integration.status == IntegrationStatus.active) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Revoke integration',
                      message:
                          'Revoke "${integration.name}"? This cannot be undone. '
                          'The integration will immediately stop working.',
                      confirmLabel: 'Revoke',
                      destructive: true,
                    );
                    if (confirmed && context.mounted) {
                      try {
                        await ref.read(integrationControllerProvider.notifier).revoke(integration.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Integration revoked')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to revoke: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Revoke', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(IntegrationStatus s) => switch (s) {
        IntegrationStatus.active => AppColors.success,
        IntegrationStatus.revoked => AppColors.error,
      };

  String _formatDate(DateTime dt) => dt.toLocal().toString().split('.').first;
}