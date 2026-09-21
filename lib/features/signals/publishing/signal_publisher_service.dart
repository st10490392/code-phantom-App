import '../domain/signal.dart';

enum PublishTarget { app, whatsApp, telegram }

/// Publishing is decoupled from signal storage/status so new channels are
/// purely additive — adding a channel never touches `SignalService`.
abstract class SignalPublisherService {
  Future<void> publish(Signal signal, {required Set<PublishTarget> targets});
}
