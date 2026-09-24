import 'package:flutter/foundation.dart';

/// Debug-only timing for a single startup stage (a secure-storage read, the
/// `/me` request, session restoration as a whole, …). Prints elapsed
/// wall-clock time to the console the moment [action] settles, so a slow
/// stage on a real low-end device shows up directly in `flutter run`
/// output without needing a profiler attached.
///
/// A complete no-op outside debug builds: `kDebugMode` is a compile-time
/// constant, so the `Stopwatch`/`debugPrint` branch is tree-shaken out of
/// profile/release builds entirely — this must never be the reason startup
/// is slow for a real user.
Future<T> traceStartup<T>(String label, Future<T> Function() action) async {
  if (!kDebugMode) return action();

  final stopwatch = Stopwatch()..start();
  try {
    return await action();
  } finally {
    stopwatch.stop();
    debugPrint('[startup] $label: ${stopwatch.elapsedMilliseconds}ms');
  }
}
