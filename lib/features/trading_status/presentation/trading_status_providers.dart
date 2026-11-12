import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/network/bridge_client.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/trading_status_service.dart';
import '../domain/trading_status.dart';

/// `null` in mock mode and in any build without `BRIDGE_BASE_URL`: every
/// consumer treats that as "no bridge configured", never as "backend down".
final bridgeClientProvider = Provider<BridgeClient?>((ref) {
  if (ref.watch(appEnvironmentProvider) == AppEnvironment.mock) return null;
  if (!ApiConfig.bridgeConfigured) return null;
  return BridgeClient(baseUrl: ApiConfig.bridgeBaseUrl);
});

final tradingStatusServiceProvider = Provider<TradingStatusService>((ref) {
  final client = ref.watch(bridgeClientProvider);
  return client == null ? NoOpTradingStatusService() : BridgeTradingStatusService(client);
});

/// Live daemon state, re-polled on [bridgePollInterval]. A failed refresh keeps
/// the last authoritative value on screen instead of blanking the dashboard —
/// same rule `pollingStream` already applies to Scanner and Signals.
final tradingStatusProvider = FutureProvider<TradingStatus>((ref) async {
  final service = ref.watch(tradingStatusServiceProvider);
  while (true) {
    try {
      final status = await service.getStatus();
      await Future<void>.delayed(bridgePollInterval);
      return status;
    } on Exception {
      await Future<void>.delayed(bridgePollInterval);
    }
  }
});

final openPositionsProvider = FutureProvider<List<LivePosition>>((ref) async {
  final service = ref.watch(tradingStatusServiceProvider);
  while (true) {
    try {
      final positions = await service.getOpenPositions();
      await Future<void>.delayed(bridgePollInterval);
      return positions;
    } on Exception {
      await Future<void>.delayed(bridgePollInterval);
    }
  }
});

final tradingPerformanceProvider = FutureProvider<TradingPerformance?>((ref) async {
  final service = ref.watch(tradingStatusServiceProvider);
  try {
    return await service.getPerformance();
  } on Exception {
    return null;
  }
});

/// The bridge's view of *this device's* licence (`GET /api/v1/license/status`
/// is the daemon's own key validity, so it is only meaningful together with the
/// account entitlements from `/me`). Kept separate from the Node backend's
/// `GET /licences` records on purpose: they are two different licence systems
/// and the UI labels them distinctly.
final bridgeLicenseStatusProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final client = ref.watch(bridgeClientProvider);
  if (client == null) return null;
  try {
    return await client.get('/license/status');
  } on Exception {
    return null;
  }
});
