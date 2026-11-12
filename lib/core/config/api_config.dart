import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app_environment.dart';

/// Centralized backend configuration — nothing in the app should hard-code
/// a URL or read `String.fromEnvironment` directly outside this file.
///
/// Environment selection: `--dart-define=APP_ENV=development` (or `prod`/
/// `production`); defaults to [AppEnvironment.mock] when omitted, so a
/// plain `flutter run` / `flutter test` never accidentally talks to a real
/// backend. Runtime code should read the environment through
/// `appEnvironmentProvider` (see `auth_providers.dart`), not this constant
/// directly — that provider is the override point tests use to select
/// `ApiAuthService` without needing a build-time flag.
///
/// Base URL resolution, in order:
///   1. `--dart-define=API_BASE_URL=...` — always wins when supplied. This
///      is how a physical device on the same LAN as a developer's machine
///      points at it (`http://<machine LAN IP>:8080/api/v1`), and how a
///      later hosted development/staging backend gets wired in — without
///      ever committing that URL to source.
///   2. A platform-aware default for [AppEnvironment.development]:
///      - Android emulator: `10.0.2.2` is the emulator's fixed alias for
///        the host machine's `localhost` (an Android tooling convention,
///        not a LAN IP — safe to commit).
///      - Everything else (desktop, iOS simulator, `flutter test`):
///        `localhost`.
///      Neither covers a physical phone on Wi-Fi — that always needs the
///      `API_BASE_URL` override above, since there is no generic alias for
///      "the developer's machine" from a physical device's network stack.
///   3. [AppEnvironment.staging] has no fixed URL of its own by design — a
///      staging deployment's host is provisioned per-repo (GitHub
///      Environment variable, see `docs/RELEASE_ANDROID.md`), so a staging
///      build must always supply `API_BASE_URL` explicitly. If it doesn't
///      (e.g. a local `flutter run --dart-define=APP_ENV=staging` with no
///      URL), this falls back to the same placeholder-style default as
///      development so the app fails obviously (connection refused) rather
///      than silently.
///   4. [AppEnvironment.production]'s base URL is a placeholder until a
///      real production backend exists; set it (or pass `API_BASE_URL` at
///      build time) before ever shipping a production build.
abstract final class ApiConfig {
  static AppEnvironment get environment =>
      AppEnvironment.fromString(const String.fromEnvironment('APP_ENV', defaultValue: 'mock'));

  static const String _explicitBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const String _explicitAuthRedirectUrl = String.fromEnvironment('AUTH_REDIRECT_URL');

  /// Where Supabase auth emails (verification, password reset, email
  /// change) send the user back to.
  ///
  /// - Android/iOS: the app's custom scheme `codephantom://auth-callback`.
  /// - Web: an HTTPS page of the deployed web app, never the custom scheme.
  ///   `--dart-define=AUTH_REDIRECT_URL=https://<web host>/auth/callback`
  ///   pins it; otherwise it is derived from the page's own origin, so one
  ///   build works on whichever host serves it. The backend only honours
  ///   URLs on its `AUTH_REDIRECT_ALLOWLIST`.
  static String get authRedirectUrl {
    if (!kIsWeb) return mobileAuthRedirectUrl;
    if (_explicitAuthRedirectUrl.isNotEmpty) return _explicitAuthRedirectUrl;
    return webAuthRedirectUrlFor(Uri.base);
  }

  static const String mobileAuthRedirectUrl = 'codephantom://auth-callback';

  /// Path of the web auth-callback route.
  static const String webAuthCallbackPath = '/auth/callback';

  static String webAuthRedirectUrlFor(Uri pageUrl) => '${pageUrl.origin}$webAuthCallbackPath';

  /// Public build flag: `--dart-define=SCANNER_REVIEW_ACTIONS=true` turns on
  /// the real Scanner approve/reject/edit calls. Off by default while the
  /// Scanner backtest is unvalidated; the backend still requires
  /// `scanner.review` for every action.
  static const bool scannerReviewActionsEnabled = bool.fromEnvironment('SCANNER_REVIEW_ACTIONS');

  /// Public build flag: `--dart-define=TRADING_CONTROLS_ENABLED=true` turns on
  /// the pause/resume control surface on the Dashboard. Off by default: the
  /// backend only queues EA commands while its `ea.remote_commands` feature
  /// flag is active, and a client-side toggle would require a control JWT the
  /// bridge does not issue to a phone (see `docs/BRIDGE_INTEGRATION.md`).
  /// Authorization is always the server's decision — this flag only decides
  /// whether the UI offers the action at all.
  static const bool tradingControlsEnabled = bool.fromEnvironment('TRADING_CONTROLS_ENABLED');

  /// The live trading bridge (`c:\CodePhantom`'s `api_server.py`), which is a
  /// *different* service from the primary API above: it owns MT5 state
  /// (`/status`, `/positions`, `/analytics`, `/control/toggle`) and the live
  /// WebSocket stream, and has no user accounts of its own. Never defaulted
  /// to a real host — a connected build must supply
  /// `--dart-define=BRIDGE_BASE_URL=http://<tailnet-ip>:8100/api/v1`
  /// explicitly, so an unconfigured build fails visibly instead of talking to
  /// someone else's daemon. Empty means "no bridge configured for this build".
  static const String _explicitBridgeBaseUrl = String.fromEnvironment('BRIDGE_BASE_URL');

  static String get bridgeBaseUrl => _explicitBridgeBaseUrl;

  /// True only when this build is pointed at a live trading bridge.
  static bool get bridgeConfigured => _explicitBridgeBaseUrl.isNotEmpty;

  /// `ws://`/`wss://` form of [bridgeBaseUrl]'s `/stream` endpoint. HTTPS
  /// origins become WSS, so a TLS deployment can never be downgraded to a
  /// plain WebSocket by accident.
  static Uri? get bridgeStreamUri {
    if (!bridgeConfigured) return null;
    final base = Uri.parse(_explicitBridgeBaseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(scheme: scheme, path: '${base.path}/stream');
  }

  /// See the class doc for the placeholder note — this is intentionally
  /// not a real host. Override with `--dart-define=API_BASE_URL=...` for
  /// any production build until a real URL is set here.
  static const String _productionBaseUrlPlaceholder = 'https://api.codephantom.example/api/v1';

  static String get baseUrl {
    if (_explicitBaseUrl.isNotEmpty) return _explicitBaseUrl;
    return switch (environment) {
      AppEnvironment.mock => '',
      AppEnvironment.development => _developmentDefaultBaseUrl,
      AppEnvironment.staging => _developmentDefaultBaseUrl,
      AppEnvironment.production => _productionBaseUrlPlaceholder,
    };
  }

  static String get _developmentDefaultBaseUrl {
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8080/api/v1';
    return 'http://localhost:8080/api/v1';
  }
}
