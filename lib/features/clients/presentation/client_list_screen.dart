import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/client_profile.dart';
import 'client_detail_screen.dart';
import 'clients_providers.dart';

class ClientListScreen extends ConsumerWidget {
  const ClientListScreen({super.key});

  Color _statusColor(ClientAccountStatus s) => switch (s) {
        ClientAccountStatus.active => AppColors.success,
        ClientAccountStatus.suspended => AppColors.warning,
        ClientAccountStatus.disabled => AppColors.error,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: clientsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: 'Could not load clients.\n$e'),
        data: (clients) {
          if (clients.isEmpty) {
            return const EmptyView(icon: Icons.groups_outlined, message: 'No clients yet.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: clients.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) {
              final client = clients[i];
              return PhantomCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ClientDetailScreen(userId: client.userId)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(client.name, style: Theme.of(context).textTheme.titleMedium),
                          Text(client.email, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    StatusBadge(label: client.status.wireValue, color: _statusColor(client.status)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
