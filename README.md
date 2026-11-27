# CodePhantom App

The CodePhantom Technologies mobile platform — Android-first, iOS-ready
Flutter app for Scanner setups, Signals, EA monitoring, Client
administration, Licence management and Notifications.

**Phase 1** (this repo, current state): architecture, design system,
navigation, role/permission system, and every module's UI/UX wired to
**mock services behind clean interfaces**, plus the native Android/iOS
platform projects. No real backend, no real Scanner or EA connection, no
real WhatsApp/Telegram integration — see
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full proposal and the
phase roadmap.

## Verified build status

Unlike the very first commit on this branch (written blind, without a
working Flutter SDK in that sandbox), every commit since has been verified
against Flutter 3.47.5 stable:

- `flutter pub get` — resolves cleanly.
- `flutter analyze` — **0 issues.**
- `flutter test` — **49/49 passing** (permissions, mock auth, scanner/signal
  workflow transitions, licence logic, module visibility, navigation
  authorization/route guards, and dashboard filtering by permission).
- `android/` and `ios/` platform projects are committed (generated via
  `flutter create .`, org `dev.codephantom`).

Not yet run in this environment: `flutter run` / `flutter build apk` against
a real device or emulator (no Android SDK or Chrome installed in this
sandbox) — see "Known gaps" below.

## First-time setup

1. Install Flutter (stable channel) — see
   [flutter.dev/docs/get-started/install](https://docs.flutter.dev/get-started/install).
   Verify with:
   ```bash
   flutter doctor
   ```
2. From the repo root, fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run static analysis:
   ```bash
   flutter analyze
   ```
4. Run the test suite:
   ```bash
   flutter test
   ```
5. Run the app (with an emulator/device connected, or `-d chrome` for a
   quick UI check):
   ```bash
   flutter run
   ```

## Mock login accounts (development only)

Shown in-app on the login screen too. **Never use this pattern for real
credentials** — Phase 2 replaces `MockAuthService` with a real backend.

| Role | Email | Password |
|---|---|---|
| OWNER | `owner@codephantom.dev` | `owner123` |
| ADMIN | `admin@codephantom.dev` | `admin123` |
| TRADER | `trader@codephantom.dev` | `trader123` |
| SCANNER_CLIENT | `scanner.client@codephantom.dev` | `client123` |
| SIGNAL_CLIENT | `signal.client@codephantom.dev` | `client123` |
| EA_CLIENT | `ea.client@codephantom.dev` | `client123` |
| INTERNAL (sample tester) | `friend@codephantom.dev` | `internal123` |

## Available roles

`OWNER`, `ADMIN`, `TRADER`, `SCANNER_CLIENT`, `SIGNAL_CLIENT`, `EA_CLIENT`,
`INTERNAL`. Roles set a **default** permission set only — actual access is
governed per-user by an independent `PermissionSet` (see
[`docs/ARCHITECTURE.md` §5](docs/ARCHITECTURE.md#5-role--permission-model)).
This is what lets two users with the same role have different module access.

## Project structure

```
lib/
  core/        theme, routing, storage, permissions, shared widgets, utilities
  features/    auth, dashboard, scanner, signals, ea, clients, licences,
               notifications, settings — each with data/domain/presentation
test/          unit + widget tests mirroring lib/'s structure
docs/          ARCHITECTURE.md (the full Phase 1 proposal)
assets/brand/  logo.png, mark.png (copied from code-phantom-website)
android/, ios/ native platform projects (generated via `flutter create .`)
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full rationale,
data models, and service interfaces.

## How mock services work

Every module talks to an **interface** (e.g. `ScannerService`,
`SignalService`, `EAService`, `ClientService`, `LicenceService`,
`NotificationService`, `AuthService`), never to JSON or a mock class
directly. Widgets depend on Riverpod providers (`lib/features/*/presentation/
*_providers.dart`), which currently resolve to a `Mock*Service`
implementation seeded with realistic in-memory data and simulated network
delay.

Scanner setups, signals, EA account data, clients, licences and
notifications are all backed by `StreamController`-based mocks, so the UI
already behaves like it's receiving live updates (approve a setup, watch it
move out of the Pending tab; generate a licence, watch it appear in the
list).

## Where future API integrations go

Nothing in `lib/features/*/presentation/` or `lib/features/*/data/*_service.dart`
(the interfaces) should need to change. Phase 2+ work is:

1. Implement `Api<X>Service implements <X>Service` per module using `dio`
   (not yet a dependency — add it when this work starts) inside each
   module's `data/` folder, next to the existing mock.
2. Swap exactly one line per module — the `Provider<XService>` in
   `*_providers.dart` — from `MockXService()` to `ApiXService(apiClient)`.
3. Everything above the service layer (repositories, if introduced, and all
   presentation code) is untouched.

Roadmap from the brief:
- **Phase 2** — real CodePhantom backend (auth, clients, licences, notifications).
- **Phase 3** — connect CPT Scanner (external engine; strategy logic stays in that product, never here).
- **Phase 4** — connect CodePhantom EA (external engine on a VPS; no execution logic here).
- **Phase 5** — WhatsApp Business publishing (`WhatsAppSignalPublisher` placeholder already exists in `lib/features/signals/publishing/`).

## Building an Android debug APK

```bash
flutter build apk --debug
```
Output: `build/app/outputs/flutter-apk/app-debug.apk`

## Building an Android release APK (later)

Requires a signing config first (`android/key.properties` + a keystore —
**never commit either**; both are already covered by `.gitignore`). Once
configured:

```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

For Play Store distribution, prefer an app bundle instead:
```bash
flutter build appbundle --release
```

## Known gaps / explicitly out of scope for Phase 1

- No real network layer (`dio`) is wired in yet — see "Where future API
  integrations go" above.
- No push notifications (FCM) — `NotificationService` is stream-based
  specifically so this is additive later.
- Launcher icons are still Flutter's default asset — swapping in
  `assets/brand/mark.png` needs per-density icon generation
  (`flutter_launcher_icons` or manual export), not done yet.
- No tablet nav rail — `AppShell` currently renders the phone bottom-nav
  bar at every width; a `NavigationRail` breakpoint for tablets (mentioned
  in `docs/ARCHITECTURE.md` §6) is deferred.
- Not run in this environment: `flutter run` / `flutter build apk` against
  a real device or emulator — no Android SDK or Chrome installed in this
  sandbox. `flutter analyze` and `flutter test` **have** been run and pass
  (see "Verified build status" above).
- Licence keys are **visual mocks only** (`CPT-SCN-7F4K-92MQ-X81P` format) —
  never treat them as secure. Real key generation/validation must happen
  server-side.

## Security principles (see `docs/ARCHITECTURE.md` §8 for detail)

- No API secrets, licence-generation secrets, or broker credentials live in
  this codebase.
- Tokens (once real auth exists) go through `flutter_secure_storage`
  (`lib/core/storage/secure_storage.dart`), never `shared_preferences`.
- Permission checks in the UI (`PermissionGate`, route guards) are a UX
  convenience, not authorization. A real backend must always be the final
  authority — this is stated directly in code comments so it isn't
  mistakenly relied upon later.

---

## Project status update — 13 October 2026

Android RC15 (`1.0.1-rc2`, code 15) signed privately, [draft PR #22](https://github.com/st10490392/code-phantom-App/pull/22), 272 Flutter tests reported passing. Staging OWNER login and persistent phone-alert setting verified; one active Android push registration exists. **Real FCM delivery not yet verified.** A later staging test-button build was started, but final signing not confirmed. This default-branch README documents an early baseline, not all later draft-branch features.

## Trading control (Flutter mobile)

Start the trading repository's paper control service with its account registry and market-data bridge, and expose it through a device-reachable HTTPS address with a trusted certificate. The trading URL is separate from the existing CodePhantom login API. Use the actual account keys from the server's `PAPER_ACCOUNTS_JSON` registry for the two account defines.

```sh
flutter pub get
flutter run --dart-define=TRADING_API_URL=https://trading.example.com --dart-define=MATCHTRADER_ACCOUNT=desk1 --dart-define=DERIV_ACCOUNT=synthetics1
```

Keep the existing login API and app environment settings. After sign-in the app verifies any saved trading license with the server. Open **Signals** or **EA**, select the profile and activate a license key. For the percentage-risk prop EA select Prop EA Mode and set `--dart-define=PROP_CORE_ACCOUNT=your_engine_id`. EA_ONLY and FULL_ACCESS require the exact MT5 login/server during first activation. The installation ID is generated locally. Subsequent requests carry the bearer license and X-Device-ID. Native devices store activation data using the existing Keychain/Keystore storage. Web builds use browser storage. Scope is revalidated online before protected data loads. Changing devices or broker bindings requires an owner reset.

SIGNALS_ONLY unlocks market direction, signals and notifications. EA_ONLY unlocks EA status and history. FULL_ACCESS enables both. Existing app role permissions still apply to navigation and control actions. **Change license** clears the locally saved activation.

**Licences** requires an owner app login and the backend OWNER_MASTER_KEY. Enter the master credential at runtime. Generate a scoped key for an existing engine account, optionally set its expiration, and copy or share the one-time key. The list shows device and MT5 bindings. Unbind and revoke require confirmation. The owner secret stays in memory while the screen is open.

In **EA ? Bot & Risk Controls ? EA setup & start**, verify the bound MT5 ID/server, select percent or fixed USD risk, enter the trade risk, daily loss limit and maximum drawdown percent, and tap **Start EA**. Paper is the default. Explicit demo broker execution requires confirmation and a matching connected bridge. MatchTrader is signal-only. Status/history show the backend shadow ledger and whether broker execution was requested. Flatten and pause requires confirmation. Broker fill verification uses MT5.

Signals use the existing Firebase mobile configuration (PUSH_ENABLED, PUSH_FIREBASE_PROJECT_ID, PUSH_FIREBASE_APP_ID, PUSH_FIREBASE_API_KEY and PUSH_FIREBASE_SENDER_ID). Use the same Firebase project as the trading backend and allow OS notifications. Signal-capable devices register FCM tokens on activation and refresh. While the app is open, a five-second account event poll also runs without Firebase. Fresh signals produce a banner and system alert sound; foreground FCM wakes the same sequence-based reader. Background delivery requires FCM and platform permission. Sound follows OS settings. To retire a registered device, reset or revoke its license in the owner screen.

Run `flutter analyze` and `flutter test` from the repository root.
