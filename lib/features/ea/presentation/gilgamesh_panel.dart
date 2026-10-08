import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_environment.dart';
import '../../auth/presentation/auth_providers.dart';

/// Read-only broker evidence. A published signal is never an executed order.
final gilgameshProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  if (ref.watch(appEnvironmentProvider) == AppEnvironment.mock) {
    return {
      'sessions': <dynamic>[],
      'events': <dynamic>[],
      'execution_enabled': false,
    };
  }
  final response = await ref.watch(apiClientProvider).get('/ea/gilgamesh');
  return response['data'] as Map<String, dynamic>;
});

class GilgameshPanel extends ConsumerWidget {
  const GilgameshPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gilgameshProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'CPT GILGAMESH EA',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh broker lifecycle',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(gilgameshProvider),
                ),
              ],
            ),
            const Text(
              'LIVE and FUNDED locked. Order submission disabled.',
            ),
            const Text(
              'Signals describe setups. Only broker evidence confirms orders, fills and outcomes.',
            ),
            const SizedBox(height: 12),
            state.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => const Text(
                'Broker lifecycle unavailable. Refresh to retry. Execution state is unknown.',
              ),
              data: (data) => _Evidence(data: data),
            ),
          ],
        ),
      ),
    );
  }
}

class _Evidence extends StatelessWidget {
  const _Evidence({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final sessions = data['sessions'] as List<dynamic>? ?? [];
    final events = data['events'] as List<dynamic>? ?? [];
    final positions = data['positions'] as List<dynamic>? ?? [];
    final stats = data['statistics'] as List<dynamic>? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sessions.isEmpty)
          const Text(
            'No verified DEMO account binding. Ask the owner to verify your broker account identifier, server and licensed device. Never share your MT5 password.',
          ),
        for (final value in sessions) ...[
          Text(
              '${value['broker_server']} • Account ${value['broker_account']}',),
          Text(
            value['revoked_at'] == null
                ? '${value['mode']} • monitoring only'
                : 'Binding revoked',
          ),
        ],
        for (final stat in stats)
          Text(
            'Session ${stat['session_id']} • Confirmed broker closes: ${stat['confirmed_closes']} • Net realized P/L: ${stat['net_profit']} (broker account currency)',
          ),
        const SizedBox(height: 8),
        const Text('Last broker position observations'),
        for (final position in positions)
          Text(
              'Position ${position['payload']['position_id']} • ${position['payload']['kind']} • Remaining volume ${position['payload']['remaining_volume'] ?? 'unknown'} • Observed ${position['observed_at']}',),
        const Text(
            'These are timestamped observations. Current broker state may have changed.',),
        const SizedBox(height: 8),
        const Text('Execution receipts and position lifecycle'),
        if (events.isEmpty)
          const Text('No broker evidence received. Position state is unknown.'),
        for (final value in events.take(30))
          _EventTile(event: value as Map<String, dynamic>),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final Map<String, dynamic> event;
  @override
  Widget build(BuildContext context) {
    final payload = event['payload'] as Map<String, dynamic>;
    final kind = payload['kind'];
    final status = payload['receipt_status'];
    final message = status == 'UNCERTAIN' || status == 'INTENT'
        ? 'Broker submission unresolved. Do not retry.'
        : status == 'EXECUTED'
            ? 'Broker order acknowledged. Check fill and position events.'
            : status == 'REJECTED'
                ? 'Broker rejected the order.'
                : '$kind';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(message),
      subtitle: Text(
        '${payload['symbol'] ?? ''} ${payload['position_id'] == null ? '' : '• Position ${payload['position_id']}'}\nObserved ${event['observed_at']}\nReceived ${event['received_at']}',
      ),
      isThreeLine: true,
    );
  }
}
