import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_environment.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/api_signal_service.dart';
import '../data/mock_signal_service.dart';
import '../data/signal_service.dart';
import '../domain/signal.dart';
import '../domain/signal_enums.dart';
import '../domain/signal_performance_summary.dart';
import '../publishing/mock_publishers.dart';
import '../publishing/signal_publisher_service.dart';

/// MOCK → [MockSignalService]; DEVELOPMENT/PRODUCTION → [ApiSignalService].
final signalServiceProvider = Provider<SignalService>((ref) {
  switch (ref.watch(appEnvironmentProvider)) {
    case AppEnvironment.mock:
      return MockSignalService();
    case AppEnvironment.development:
    case AppEnvironment.production:
      return ApiSignalService(ref.watch(apiClientProvider));
  }
});

final signalPublisherServiceProvider = Provider<SignalPublisherService>(
  (ref) => CompositeSignalPublisher([
    AppSignalPublisher(),
    WhatsAppSignalPublisher(),
    TelegramSignalPublisher(),
  ]),
);

final signalsByStatusProvider =
    StreamProvider.family<List<Signal>, SignalStatus?>((ref, status) {
  return ref.watch(signalServiceProvider).watchSignals(status: status);
});

final activeSignalsProvider = StreamProvider<List<Signal>>((ref) {
  return ref.watch(signalServiceProvider).watchSignals().map(
        (all) => all.where((s) => s.status.isActive).toList(),
      );
});

final closedSignalsProvider = StreamProvider<List<Signal>>((ref) {
  return ref.watch(signalServiceProvider).watchSignals().map(
        (all) => all.where((s) => s.status.isClosed).toList(),
      );
});

final signalPerformanceProvider = FutureProvider<SignalPerformanceSummary>((ref) async {
  // Re-computed whenever the underlying signal stream changes.
  ref.watch(signalsByStatusProvider(null));
  return ref.watch(signalServiceProvider).performanceSummary();
});
