import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifications/push/firebase_push_transport.dart';
import '../auth/presentation/auth_providers.dart';
import 'license_controller.dart';
import 'trading_service.dart';

/// FCM wakes the durable queue reader. The queue supplies account-authorized
/// content and sequence numbers for both foreground transports.
class TradingAlerts extends ConsumerStatefulWidget {
  const TradingAlerts({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<TradingAlerts> createState() => _AlertsState();
}

class _AlertsState extends ConsumerState<TradingAlerts> {
  TradingService? current;
  Timer? timer;
  StreamSubscription<dynamic>? foreground, refreshToken;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      licenseProvider,
      (_, next) => bind(next.asData?.value),
      fireImmediately: true,
    );
  }

  Future<void> bind(TradingService? api) async {
    if (identical(api, current)) return;
    current = api;
    final revision = ++generation;
    timer?.cancel();
    foreground?.cancel();
    refreshToken?.cancel();
    if (api == null || !api.signals) return;
    bool active() => mounted && revision == generation;
    final store = ref.read(licenseStore);
    final key =
        'trading.cursor.$tradingUrl.${ref.read(currentUserProvider)?.id}.${api.profile.account}';
    int cursor = int.tryParse(await store.read(key) ?? '') ?? 0;
    if (!active()) return;
    bool pending = false;
    Future<void> poll() async {
      if (pending || !active()) return;
      pending = true;
      try {
        final events = (await api.dio.get<List>(
          '/notifications/events',
          queryParameters: {'after': cursor},
        ))
            .data!;
        for (final event in events) {
          if (!active()) return;
          final seq = event['sequence'] as int;
          if (seq <= cursor) continue;
          cursor = seq;
          final alert = event['alert'];
          final opened = alert['opened_at'];
          if (opened is num &&
              DateTime.now().millisecondsSinceEpoch / 1000 - opened < 120) {
            if (!mounted) return;
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text(
                  "${alert['symbol']} · ${alert['side']} · ${alert['strategy']}",
                ),
              ),
            );
            unawaited(SystemSound.play(SystemSoundType.alert));
          }
        }
        if (events.isNotEmpty && active()) await store.write(key, '$cursor');
      } catch (_) {/* Retry on the next poll. */} finally {
        pending = false;
      }
    }

    timer = Timer.periodic(const Duration(seconds: 5), (_) => poll());
    unawaited(poll());
    if (!PhonePushConfig.configured) return;
    try {
      final transport = await FirebasePushTransport.create();
      if (!active() || !await transport.permission(prompt: true) || !active()) {
        return;
      }
      Future<void> register(String token) async {
        if (!active()) return;
        try {
          await api.dio
              .post('/notifications/register-device', data: {'token': token});
        } catch (_) {/* The queue remains available. */}
      }

      refreshToken = transport.tokenRefresh.listen(register);
      foreground = FirebaseMessaging.onMessage.listen((m) {
        if (m.data.containsKey('alert_id')) poll();
      });
      final token = await transport.token();
      if (token != null) await register(token);
    } catch (_) {/* Firebase is optional for foreground delivery. */}
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    foreground?.cancel();
    refreshToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
