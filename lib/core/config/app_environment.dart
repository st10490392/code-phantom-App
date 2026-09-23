/// Which backend the app talks to.
///
/// - [mock]: no network at all — `MockAuthService` and every other
///   `Mock*Service` in `lib/features/*/data/`.
/// - [development]: the real CodePhantom backend, pointed at a
///   developer-controlled URL (see `api_config.dart`).
/// - [production]: the real CodePhantom backend's production URL, once one
///   exists.
///
/// [development] and [production] both select `ApiAuthService` for this
/// milestone — only auth is real so far; Scanner/Signals/EA/Clients/
/// Licences/Notifications stay mock-backed in every environment until their
/// own migration milestones.
enum AppEnvironment {
  mock,
  development,
  production;

  static AppEnvironment fromString(String value) => switch (value.toLowerCase()) {
        'development' || 'dev' => AppEnvironment.development,
        'production' || 'prod' => AppEnvironment.production,
        _ => AppEnvironment.mock,
      };
}
