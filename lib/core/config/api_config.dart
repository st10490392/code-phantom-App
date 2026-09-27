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

  /// Public build flag: `--dart-define=SCANNER_REVIEW_ACTIONS=true` turns on
  /// the real Scanner approve/reject/edit calls. Off by default while the
  /// Scanner backtest is unvalidated; the backend still requires
  /// `scanner.review` for every action.
  static const bool scannerReviewActionsEnabled = bool.fromEnvironment('SCANNER_REVIEW_ACTIONS');

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
