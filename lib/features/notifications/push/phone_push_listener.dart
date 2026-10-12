import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/routing/app_router.dart';
import '../../auth/presentation/auth_providers.dart';
import '../presentation/notifications_providers.dart';
import '../../signals/presentation/signals_providers.dart';
import 'phone_push_controller.dart';
import 'phone_push_providers.dart';

class PhonePushListener extends ConsumerStatefulWidget {
  const PhonePushListener({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<PhonePushListener> createState() => _PhonePushListenerState();
}

class _PhonePushListenerState extends ConsumerState<PhonePushListener> with WidgetsBindingObserver {
  late final PhonePushController _push;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _push = ref.read(phonePushControllerProvider);
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(
      authControllerProvider,
      (_, auth) {
        unawaited(_push.setUser(auth.status == AuthStatus.authenticated ? auth.user?.id : null));
      },
      fireImmediately: true,
    );
    _subscriptions.add(
      _push.foreground.listen(
        (alert) {
          if (!mounted || ref.read(currentUserProvider) == null) return;
          ref.invalidate(notificationListProvider);
          ref.invalidate(signalsByStatusProvider);
          ref.invalidate(activeSignalsProvider);
          ref.invalidate(closedSignalsProvider);
          ref.invalidate(signalPerformanceProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(alert.title),
              action: SnackBarAction(label: 'View', onPressed: () => ref.read(appRouterProvider).go(alert.signalPath)),
            ),
          );
        },
      ),
    );
    _subscriptions.add(
      _push.opened.listen(
        (alert) {
          if (!mounted) return;
          ref.invalidate(notificationListProvider);
          ref.read(appRouterProvider).go(alert.signalPath);
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_push.resume());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final sub in _subscriptions) { unawaited(sub.cancel()); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class PhonePushSettings extends ConsumerWidget {
  const PhonePushSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final push = ref.watch(phonePushControllerProvider);
    if (!push.available) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: push,
      builder: (context, _) => Column(
        children: [
          SwitchListTile(
            title: const Text('Signal alerts'),
            subtitle: Text(push.error ?? (push.enabled && !push.registered
                ? 'Phone alert registration is pending.'
                : 'New signals and take-profit or stop-loss results.')),
            value: push.enabled,
            onChanged: push.busy ? null : (value) => unawaited(value ? push.enable() : push.disable()),
          ),
          if (push.error != null && push.enabled)
            TextButton(onPressed: push.busy ? null : () => unawaited(push.resume()), child: const Text('Retry')),
        ],
      ),
    );
  }
}
