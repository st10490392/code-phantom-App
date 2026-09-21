import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/permissions/permission.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/client_profile.dart';
import 'clients_providers.dart';

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({required this.userId, super.key});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Client')),
      body: clientsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'Could not load client.\n$e'),
        data: (clients) {
          final client = clients.where((c) => c.userId == userId).firstOrNull;
          if (client == null) {
            return const EmptyView(message: 'Client not found.');
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              PhantomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: Theme.of(context).textTheme.headlineSmall),
                    Text(client.email, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.md),
                    _row('Status', client.status.wireValue),
                    _row('Joined', client.joinedAt.toLocal().toString().split(' ').first),
                    _row('Last login', client.lastLoginAt.toLocal().toString().split(' ').first),
                    _row('Licence status', client.licenceStatus),
                    if (client.licenceExpiry != null)
                      _row('Licence expiry', client.licenceExpiry!.toLocal().toString().split(' ').first),
                    _row('Devices', '${client.registeredDevices.length}'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Service access', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              PhantomCard(
                child: Column(
                  children: [
                    for (final permission in Permission.values)
                      _PermissionToggleRow(client: client, permission: permission),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: PhantomButton(
                      label: client.status == ClientAccountStatus.suspended
                          ? 'Reactivate'
                          : 'Suspend',
                      variant: PhantomButtonVariant.secondary,
                      onPressed: () async {
                        final service = ref.read(clientServiceProvider);
                        if (client.status == ClientAccountStatus.suspended) {
                          await service.reactivate(client.userId);
                        } else {
                          final confirmed = await showConfirmDialog(
                            context,
                            title: 'Suspend account',
                            message: 'Suspend ${client.name}\'s account?',
                            confirmLabel: 'Suspend',
                          );
                          if (confirmed) await service.suspend(client.userId);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.mutedText)),
            Text(value),
          ],
        ),
      );
}

/// Visually-clear service permission toggle, per brief ("Make the service
/// permissions toggles visually clear").
class _PermissionToggleRow extends ConsumerWidget {
  const _PermissionToggleRow({required this.client, required this.permission});
  final ClientProfile client;
  final Permission permission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = client.servicePermissions.has(permission);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(permission.wireValue.replaceAll('_', ' ')),
      value: enabled,
      activeThumbColor: AppColors.electricBlue,
      onChanged: (value) async {
        final updated = value
            ? client.servicePermissions.grant(permission)
            : client.servicePermissions.revoke(permission);
        await ref.read(clientServiceProvider).setServiceAccess(client.userId, updated);
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
