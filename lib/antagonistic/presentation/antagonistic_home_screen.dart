import 'package:flutter/material.dart';

import '../core/antagonistic_theme.dart';
import '../domain/execution_route.dart';

class AntagonisticHomeScreen extends StatelessWidget {
  const AntagonisticHomeScreen({super.key});

  static const _legacyLogoUrl =
      'https://raw.githubusercontent.com/st10490392/AntagonisticTradingCo/main/logo.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antagonistic Trader'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'CodePhantom Technologies',
                style: TextStyle(
                  color: AntagonisticTheme.muted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  _legacyLogoUrl,
                  width: 112,
                  height: 112,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 112,
                    height: 112,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AntagonisticTheme.surface,
                      ),
                      child: Icon(
                        Icons.show_chart,
                        size: 56,
                        color: AntagonisticTheme.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Private trading infrastructure',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Founder-first synthetic research and execution. Strategy code, '
              'broker credentials and licence authority stay server-side.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AntagonisticTheme.muted),
            ),
            const SizedBox(height: 24),
            const _StatusCard(
              title: 'Synthetic Engine',
              value: 'Research / Shadow',
              icon: Icons.auto_graph,
              color: AntagonisticTheme.warning,
            ),
            const SizedBox(height: 12),
            const _StatusCard(
              title: 'Licence',
              value: 'Founder access',
              icon: Icons.key,
              color: AntagonisticTheme.success,
            ),
            const SizedBox(height: 12),
            const _StatusCard(
              title: 'Automation',
              value: 'Fail-closed',
              icon: Icons.security,
              color: AntagonisticTheme.accent,
            ),
            const SizedBox(height: 24),
            Text(
              'Execution adapters',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            ...AntagonisticExecutionRoute.values.map(
              (route) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    route == AntagonisticExecutionRoute.derivApi
                        ? Icons.cloud_outlined
                        : Icons.desktop_windows_outlined,
                    color: AntagonisticTheme.accent,
                  ),
                  title: Text(route.label),
                  subtitle: Text(route.description),
                  trailing: const Icon(Icons.lock_outline),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'AT-001 establishes the private app boundary only. Real trading '
              'remains disabled until a synthetic strategy and its execution '
              'adapter pass shadow/demo validation.',
              style: TextStyle(
                color: AntagonisticTheme.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
