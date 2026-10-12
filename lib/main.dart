import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';
import 'core/config/api_config.dart';
import 'core/platform/browser_location.dart';
import 'features/auth/presentation/auth_callback_screen.dart';
import 'features/notifications/push/firebase_push_transport.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (PhonePushConfig.configured && !kIsWeb) {
    await initializePushFirebase();
    FirebaseMessaging.onBackgroundMessage(firebasePushBackgroundHandler);
  }
  Uri? pendingAuthCallback;
  if (kIsWeb) {
    // Real paths (/scanner/setup/42) instead of /#/…, so links and refresh
    // work; the host rewrites unknown paths to index.html (docs/WEB.md).
    usePathUrlStrategy();
    pendingAuthCallback = captureWebAuthCallback(Uri.base);
  }
  runApp(
    ProviderScope(
      overrides: [
        if (pendingAuthCallback != null) pendingWebAuthCallbackProvider.overrideWith((ref) => pendingAuthCallback),
      ],
      child: const CodePhantomApp(),
    ),
  );
}

/// If the page was opened from an auth email (`/auth/callback#access_token=…`),
/// keep that URL in memory and immediately replace the address-bar entry
/// with the bare path so tokens never remain in the URL or browser history.
Uri? captureWebAuthCallback(Uri pageUrl) {
  if (pageUrl.path != ApiConfig.webAuthCallbackPath) return null;
  if (pageUrl.fragment.isEmpty && !pageUrl.hasQuery) return null;
  replaceBrowserUrl(ApiConfig.webAuthCallbackPath);
  return pageUrl;
}
