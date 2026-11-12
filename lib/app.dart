import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'features/live_feed/presentation/live_feed_providers.dart';
import 'features/notifications/push/phone_push_listener.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/brand_assets.dart';

class CodePhantomApp extends ConsumerWidget {
  const CodePhantomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Owns the live trading feed's lifetime for the whole app lifetime: it
    // subscribes when a session exists and unsubscribes on sign-out. Watching
    // it here is what keeps the feed alive while the app runs; the provider
    // itself holds no state of its own.
    ref.watch(liveFeedBootstrapProvider);
    // Built once and reused for both slots below — `themeMode` is pinned to
    // dark, so `theme` (the light-mode slot) is never actually rendered,
    // but MaterialApp still requires it, and building a second, identical
    // ThemeData for it on every rebuild is pure waste.
    final theme = AppTheme.dark();

    return MaterialApp.router(
      title: BrandAssets.companyFullName,
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      builder: (context, child) => PhonePushListener(child: child ?? const SizedBox.shrink()),
    );
  }
}

