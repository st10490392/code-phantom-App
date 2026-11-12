import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/live_feed_service.dart';
import '../data/live_feed_transport.dart';
import '../domain/live_feed_event.dart';

final liveFeedServiceProvider = Provider<LiveFeedService>((ref) {
  if (ref.watch(appEnvironmentProvider) == AppEnvironment.mock) {
    final service = MockLiveFeedService();
    ref.onDispose(service.dispose);
    return service;
  }
  final service = BridgeLiveFeedService(
    credentials: ref.watch(bridgeCredentialStorageProvider),
    identity: ref.watch(deviceIdentityProvider),
    transport: WebSocketLiveFeedTransport(),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Connection state of the live feed. Never defaults to "live": an
/// unconfigured or unauthenticated build reports exactly that.
final liveFeedStatusProvider = StreamProvider<LiveFeedStatus>((ref) {
  final service = ref.watch(liveFeedServiceProvider);
  final controller = StreamController<LiveFeedStatus>();
  final subscription = service.statuses.listen(controller.add);
  // The current state is re-emitted on listen so a screen opened after
  // startup shows the real state rather than "loading".
  controller.add(service is BridgeLiveFeedService ? service.status : LiveFeedStatus.unconfigured);
  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Most recent distinct events, newest first, capped at 25. Duplicate frames
/// are already suppressed inside the service, so this list is one entry per
/// real event rather than one per socket frame.
final liveFeedEventsProvider = StreamProvider<List<LiveFeedEvent>>((ref) {
  final service = ref.watch(liveFeedServiceProvider);
  final controller = StreamController<List<LiveFeedEvent>>();
  final buffer = <LiveFeedEvent>[];
  final subscription = service.events.listen((event) {
    buffer.insert(0, event);
    if (buffer.length > 25) buffer.removeLast();
    controller.add(List<LiveFeedEvent>.unmodifiable(buffer));
  });
  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Raised when the feed gives up or refuses the key, for the dashboard banner.
final liveFeedProblemProvider = StreamProvider<String>((ref) {
  final service = ref.watch(liveFeedServiceProvider);
  final controller = StreamController<String>();
  final subscription = service.problems.listen(controller.add);
  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Owns the feed's lifetime for the app's lifetime: subscribes while a session
/// exists, unsubscribes on sign-out, and disposes the service with the scope.
///
/// The stored `SIGNALS` key survives signing out — it binds the *device* to the
/// licence, not the session — but no socket stays open while signed out, and the
/// key is dropped from secure storage only by an explicit "forget this key".
final liveFeedBootstrapProvider = Provider<void>((ref) {
  final service = ref.watch(liveFeedServiceProvider);
  ref.onDispose(service.dispose);

  void apply(Object? user) {
    if (user == null) {
      unawaited(service.stop());
    } else {
      unawaited(service.start());
    }
  }

  apply(ref.read(currentUserProvider));
  ref.listen(currentUserProvider, (previous, next) => apply(next));
});

/// Re-subscribes the feed after a licence activation binds this device, so the
/// new key is used without restarting the app.
Future<void> restartLiveFeed(WidgetRef ref) => ref.read(liveFeedServiceProvider).restart();

/// Removes the stored key from secure storage and drops the subscription.
Future<void> clearLiveFeedCredentials(WidgetRef ref) async {
  await ref.read(bridgeCredentialStorageProvider).clearSignalsKey();
  await ref.read(liveFeedServiceProvider).stop();
}
