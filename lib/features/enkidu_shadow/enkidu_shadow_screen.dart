import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/presentation/auth_providers.dart';

/// A second, local build gate. The backend flag and OWNER check remain authoritative.
final enkiduShadowViewEnabledProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment(
    'ENKIDU_SHADOW_VIEW_ENABLED',
    defaultValue: false,
  ),
);

final enkiduShadowObservationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  if (!ref.watch(enkiduShadowViewEnabledProvider) ||
      ref.watch(currentUserProvider)?.isOwner != true) {
    return const <Map<String, dynamic>>[];
  }
  final response =
      await ref.watch(apiClientProvider).get('/enkidu-shadow/observations');
  return (response['data'] as List<dynamic>).cast<Map<String, dynamic>>();
});

class EnkiduShadowScreen extends ConsumerWidget {
  const EnkiduShadowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final observations = ref.watch(enkiduShadowObservationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ENKIDU V5 SHADOW')),
      body: observations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Owner SHADOW observations unavailable.'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(enkiduShadowObservationsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rows) => rows.isEmpty
            ? const Center(child: Text('No owner SHADOW observations.'))
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(enkiduShadowObservationsProvider);
                  await ref.read(enkiduShadowObservationsProvider.future);
                },
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['symbol']} ${row['direction']} · ${row['state']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'SHADOW · theoretical, no broker order or realized profit\n'
                              'Observed UTC: ${row['observed_at']}\n'
                              'Closed-candle cutoff UTC: ${row['cutoff_at']}\n'
                              'Expires UTC: ${row['expires_at']}\n'
                              'Entry ${row['entry']} · SL ${row['stop_loss']} · TP ${row['take_profit']}\n'
                              'Run: ${row['run_id']} · Source: ${row['source_sha256']}\n'
                              'Gate policy: ${row['gate_policy_sha256']}\n'
                              'Gate receipt: ${row['gate_receipt_sha256']}\n'
                              'Strategy: ${row['strategy_sha256']}',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
