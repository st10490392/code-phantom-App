import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/signal.dart';
import 'signals_providers.dart';
import 'widgets/signal_card.dart';

class SignalsScreen extends StatelessWidget {
  const SignalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Signals'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Closed'),
              Tab(text: 'History'),
              Tab(text: 'Performance'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SignalList(providerType: _ListType.active),
            _SignalList(providerType: _ListType.closed),
            _SignalList(providerType: _ListType.history),
            _PerformanceTab(),
          ],
        ),
      ),
    );
  }
}

enum _ListType { active, closed, history }

class _SignalList extends ConsumerWidget {
  const _SignalList({required this.providerType});
  final _ListType providerType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = switch (providerType) {
      _ListType.active => ref.watch(activeSignalsProvider),
      _ListType.closed => ref.watch(closedSignalsProvider),
      _ListType.history => ref.watch(signalsByStatusProvider(null)),
    };

    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Could not load signals.\n$e'),
      data: (List<Signal> signals) {
        if (signals.isEmpty) {
          return const EmptyView(icon: Icons.show_chart_outlined, message: 'No signals here yet.');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: signals.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) => SignalCard(signal: signals[i]),
        );
      },
    );
  }
}

class _PerformanceTab extends ConsumerWidget {
  const _PerformanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(signalPerformanceProvider);
    return summaryAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Could not load performance.\n$e'),
      data: (summary) => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          PhantomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Win / Loss', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Text('${summary.wins} wins · ${summary.losses} losses'),
                Text('Win rate: ${summary.winRatePercent.toStringAsFixed(1)}%'),
                Text('Avg R multiple: ${summary.averageRMultiple.toStringAsFixed(2)}R'),
                Text('Total closed signals: ${summary.totalSignals}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
