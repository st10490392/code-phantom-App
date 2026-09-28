/// Which backend the app talks to.
///
/// - [mock]: no network at all — `MockAuthService` and every other
///   `Mock*Service` in `lib/features/*/data/`.
/// - [development]: the real CodePhantom backend, pointed at a
///   developer-controlled URL (see `api_config.dart`).
/// - [staging]: the real CodePhantom backend's staging deployment — real
///   data, real auth, but not the production database. Builds distributed
///   for internal/QA testing (`.github/workflows/android-release.yml`'s
///   manual "staging" runs) use this. Distinguishing it from [production]
///   is not cosmetic: the backend itself reports its own `APP_ENV` as
///   `"staging"` on `GET /health` (see `src/config/env.ts` in
///   code-phantom-backend), and a build that lies about which one it is
///   makes on-device diagnostics (see `DiagnosticsScreen`) useless for
///   telling the two apart.
/// - [production]: the real CodePhantom backend's production deployment.
///
/// [development], [staging], and [production] all select the real `Api*`
/// implementation of every service that has one (`ApiAuthService`,
/// `ApiScannerService`, `ApiSignalService`, `ApiEAService`, …) — only
/// modules with no `Api*Service` yet (Clients, Licences, Notifications as
/// of this milestone) stay mock-backed regardless of environment. Every
/// such selection in this codebase branches on `== AppEnvironment.mock`
/// (never on which specific non-mock value), so adding this value only
/// required updating the one place that previously enumerated the other
/// two by name instead (`authServiceProvider`'s exhaustive `switch`).
enum AppEnvironment {
  mock,
  development,
  staging,
  production;

  static AppEnvironment fromString(String value) => switch (value.toLowerCase()) {
        'development' || 'dev' => AppEnvironment.development,
        'staging' || 'stage' => AppEnvironment.staging,
        'production' || 'prod' => AppEnvironment.production,
        _ => AppEnvironment.mock,
      };

  /// Short, unambiguous label for diagnostics/logging — never used for
  /// routing decisions (those always compare the enum value itself).
  String get label => switch (this) {
        AppEnvironment.mock => 'Mock',
        AppEnvironment.development => 'Development',
        AppEnvironment.staging => 'Staging',
        AppEnvironment.production => 'Production',
      };
}
