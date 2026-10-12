import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/api_signal_service.dart';
import '../domain/signal.dart';
import 'widgets/signal_card.dart';

/// Always load through the authenticated API. A push UUID is not a grant.
final entitledSignalProvider = FutureProvider.autoDispose.family<Signal, String>((ref, id) async {
  if (ref.watch(currentUserProvider) == null) throw StateError('Sign in required');
  if (!RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$').hasMatch(id)) {
    throw ArgumentError('Invalid signal reference');
  }
  final response = await ref.watch(apiClientProvider).get('/signals/$id');
  return signalFromBackendJson(response['data'] as Map<String, dynamic>);
});

class SignalDetailScreen extends ConsumerWidget {
  const SignalDetailScreen({required this.signalId, super.key});
  final String signalId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Signal')),
    body: ref.watch(entitledSignalProvider(signalId)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Signal unavailable or access has ended.'),
        TextButton(onPressed: () => ref.invalidate(entitledSignalProvider(signalId)), child: const Text('Retry')),
      ],),),
      data: (signal) => RefreshIndicator(
        onRefresh: () => ref.refresh(entitledSignalProvider(signalId).future).then((_) {}),
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [SignalCard(signal: signal)]),
      ),
    ),
  );
}
