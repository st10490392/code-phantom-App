import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/scaffold.dart';
import '../../../core/ui/error.dart';
import '../../../core/ui/loading.dart';
import '../../../core/permissions/app_role.dart';
import 'integrations_providers.dart';
import 'create_integration_sheet.dart';

/// Owner-only screen for managing platform integrations.
///
/// Displays a list of owned integrations with status and metadata.
/// Allows creating new SCANNER_PUBLISHER integrations and revoking existing ones.
class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final integrationsAsync = ref.watch(integrationsProvider);

    return AppScaffold(
      title: 'Integrations',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => showModalBottomSheet<Integration>(
            context: context,
            isScrollControlled: true,
            builder: (context) => const CreateIntegrationSheet(),
          ).then((newIntegration) {
            if (newIntegration != null && context.mounted) {
              _showSecretDialog(context, newIntegration);
            }
          }),
        ),
      ],
      body: integrationsAsync.when(
        data: (integrations) {
          if (integrations.isEmpty) {
            return const Center(
              child: Text('No integrations yet. Tap the + button to create one.'),
            );
          }
          return ListView.separated(
            itemCount: integrations.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final integration = integrations[index];
              return ListTile(
                title: Text(integration.name),
                subtitle: Text('${integration.type.wireValue} • ${integration.status.wireValue}'),
                trailing: integration.status.isRevoked
                    ? const Icon(Icons.cancel, color: Colors.red)
                    : IconButton(
                        icon: const Icon(Icons.revoke_credentials),
                        onPressed: () => _handleRevoke(context, ref, integration.id),
                      ),
              );
            },
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => AppErrorDisplay(error: error),
      ),
    );
  }

  void _handleRevoke(BuildContext context, WidgetRef ref, String integrationId) {
    final controller = ref.read(integrationControllerProvider.notifier);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Integration?'),
        content: const Text('This will immediately revoke the integration key. The integration will no longer be able to authenticate.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              controller.revoke(integrationId);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  void _showSecretDialog(BuildContext context, Integration integration) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Integration Key'),
        content: SelectableText(
          integration.plaintextSecret ?? '',
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

extension on IntegrationStatus {
  bool get isRevoked => this == IntegrationStatus.revoked;
}