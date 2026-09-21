import '../domain/signal.dart';
import 'signal_publisher_service.dart';

/// Publishes into the CodePhantom app itself (in-app signal feed / mobile
/// notification). This is the only publisher wired to anything real-ish in
/// Phase 1 (it just records intent in memory).
class AppSignalPublisher implements SignalPublisherService {
  final List<Signal> published = [];

  @override
  Future<void> publish(Signal signal, {required Set<PublishTarget> targets}) async {
    if (!targets.contains(PublishTarget.app)) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    published.add(signal);
  }
}

/// Placeholder only — per brief, do NOT integrate WhatsApp yet. This class
/// exists purely so the abstraction (`SignalPublisherService`) is proven out
/// with more than one implementation; it makes no network calls.
class WhatsAppSignalPublisher implements SignalPublisherService {
  @override
  Future<void> publish(Signal signal, {required Set<PublishTarget> targets}) async {
    if (!targets.contains(PublishTarget.whatsApp)) return;
    // Intentionally a no-op placeholder. Phase 5 replaces this with a real
    // WhatsApp Business API integration behind the same interface.
  }
}

/// Placeholder only, same rationale as [WhatsAppSignalPublisher].
class TelegramSignalPublisher implements SignalPublisherService {
  @override
  Future<void> publish(Signal signal, {required Set<PublishTarget> targets}) async {
    if (!targets.contains(PublishTarget.telegram)) return;
    // Intentionally a no-op placeholder.
  }
}

/// Fans a publish request out to every configured channel's publisher.
class CompositeSignalPublisher implements SignalPublisherService {
  CompositeSignalPublisher(this._publishers);
  final List<SignalPublisherService> _publishers;

  @override
  Future<void> publish(Signal signal, {required Set<PublishTarget> targets}) async {
    for (final publisher in _publishers) {
      await publisher.publish(signal, targets: targets);
    }
  }
}
