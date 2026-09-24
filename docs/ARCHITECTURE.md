# CodePhantom App — Architecture Proposal (Phase 1)

This document is the FIRST TASK deliverable: architecture recommendation, folder
structure, core data models, service/repository interfaces, role/permission
model, navigation structure, and the design system — derived from the
`code-phantom-website` repo — before any large-scale implementation begins.

## 1. Recommended stack

| Concern            | Choice                                   | Why |
|---------------------|-------------------------------------------|-----|
| Framework           | Flutter (stable channel), null-safe Dart  | Single codebase, Android-first, iOS-ready. |
| State management    | **Riverpod** (`flutter_riverpod` + `riverpod_annotation`/`riverpod_generator`) | Requested by brief. Compile-safe DI (no `BuildContext` lookups for services), testable in isolation (override providers with mocks), scoped/family providers fit per-role and per-module state well, no boilerplate `Provider`/`Consumer` widget nesting like plain `provider`, and it avoids the actor-model ceremony of `bloc` for what is mostly "fetch → cache → display → mutate" screens. Riverpod's `Notifier`/`AsyncNotifier` classes map 1:1 onto each feature's repository calls, which keeps widgets thin. |
| Routing             | `go_router` | Declarative routes, deep-link ready, supports route guards (used for permission-gated routes) and `ShellRoute` (used for the persistent bottom nav / drawer shell). |
| Networking (future) | `dio` behind the service interfaces described below | Not wired yet — Phase 1 ships only mock implementations, but interfaces are written so a `Dio`-based implementation is a drop-in replacement. |
| Local storage       | `flutter_secure_storage` (tokens, future secrets) + `shared_preferences` (non-sensitive UI prefs) | Matches the "never store secrets in plain local storage" requirement. |
| Modelling/serialization | `freezed` + `json_serializable` | Immutable models, generated `copyWith`/equality/`fromJson`/`toJson`, keeps the JSON contracts adaptable per the brief. |
| Testing            | `flutter_test`, `mocktail`, `riverpod` test utilities | Unit tests for services/repos/permission logic, widget tests for key screens. |

No backend, auth provider, or push-notification SDK is wired in Phase 1 — the
architecture only leaves clean seams for them (see §5 and §9).

## 2. Proposed folder structure

```
lib/
  main.dart
  core/
    theme/                 # AppColors, AppTypography, AppSpacing, AppRadius,
                            # AppShadows, AppTheme, BrandAssets
    routing/                # go_router config + permission-based route guards
    networking/             # ApiClient interface, DioApiClient (future), ApiException
    storage/                # SecureStorage, PreferencesStore wrappers
    permissions/            # Role, Permission, PermissionSet, PermissionGate widget
    widgets/                # PhantomButton, PhantomCard, StatusBadge, PhantomChip,
                            # PhantomTextField, PhantomModalSheet, ConfirmDialog,
                            # LoadingView, ErrorView, EmptyView, PhantomAppBar,
                            # BrandMark / logo widgets
    models/                 # Shared value objects (Money, Percent, TimeRange...)
    utilities/              # formatters, validators, id generation (mock), extensions
  features/
    auth/
      data/                 # AuthService interface + MockAuthService, TokenStore
      domain/                # AuthUser, AuthSession, AuthState
      presentation/          # SplashScreen, LoginScreen, ForgotPasswordScreen,
                              # RegisterPlaceholderScreen, auth_providers.dart
    dashboard/
      data/ domain/ presentation/     # summary aggregation across modules (reads
                                       # from the other features' repositories)
    scanner/
      data/                  # ScannerService interface + MockScannerService
      domain/                 # ScannerSetup, SetupStatus, Bias, Session enums
      presentation/            # PendingTab, ApprovedTab, RejectedTab, HistoryTab,
                                # SetupDetailSheet, ApproveRejectDialog
    signals/
      data/ domain/ presentation/     # SignalService, Signal, SignalStatus,
                                       # ActiveSignalsView, ClosedSignalsView,
                                       # PerformanceView
      publishing/              # SignalPublisherService + Mock/App/WhatsApp/
                                # Telegram publisher stubs (shared by scanner+signals)
    ea/
      data/                    # EAService, EAAccountService, EAControlService
      domain/                   # EAAccount, RiskMode, EAStatus
      presentation/              # EADashboardScreen, RiskControlsSheet
    clients/
      data/ domain/ presentation/     # ClientService, ClientProfile, ClientListScreen,
                                       # ClientDetailScreen, permission-toggle UI
    licences/
      data/ domain/ presentation/     # LicenceService, Licence, LicenceStatus,
                                       # GenerateLicenceSheet, LicenceListScreen
    notifications/
      data/ domain/ presentation/     # NotificationService, AppNotification,
                                       # NotificationPriority, NotificationCentreScreen
    settings/
      presentation/            # SettingsScreen, ProfileScreen, AboutScreen (logo/brand)
  app.dart                    # MaterialApp.router + ProviderScope wiring
test/
  core/permissions/          # permission_test.dart
  features/auth/             # mock_auth_service_test.dart
  features/scanner/          # scanner_workflow_test.dart (status transitions)
  features/licences/         # licence_logic_test.dart
  widget/                    # a handful of key widget tests
```

Each feature keeps `data/domain/presentation` internally, per the brief; nothing
is a "giant folder of screens."

## 3. Core data models (Phase 1 shape — not final contracts)

All models are `freezed` classes with `fromJson`/`toJson`; enums use
`@JsonValue` so wire values stay stable independent of Dart identifier names.

- **Auth**: `AuthUser { id, email, displayName, role, permissions }`,
  `AuthSession { user, accessToken, refreshToken?, expiresAt }`.
- **Role/Permission**: see §5.
- **ScannerSetup**: `id, symbol, timeframe, direction(BUY/SELL), entry, stopLoss,
  takeProfits[tp1,tp2,tp3], weeklyBias, dailyBias, session, confluenceScore,
  confluenceMaximum, status, detectedAt, notes?, chartImageUrl?`.
- **Signal**: `id, setupId?, symbol, direction, entry, stopLoss, takeProfits[],
  status, session, openedAt, closedAt?, result?, rMultiple?, notes?`.
  `SignalStatus`: PENDING, APPROVED, PUBLISHED, ACTIVE, TP1_HIT, TP2_HIT,
  TP3_HIT, STOPPED, CANCELLED, CLOSED.
- **EAAccount**: `accountId, nickname, broker, status(ONLINE/OFFLINE),
  tradingEnabled, riskMode(STANDARD/PROP_FIRM/AGGRESSIVE), riskPercentage,
  balance, equity, dailyProfit, dailyDrawdown, weeklyDrawdown?, openTrades,
  lastHeartbeat, serverStatus`.
- **ClientProfile**: `userId, name, email, status, joinedAt, lastLoginAt,
  servicePermissions(PermissionSet), licenceStatus, licenceExpiry?,
  registeredDevices[]`.
- **Licence**: `id, key, userId, product, createdAt, activatedAt?, expiresAt?,
  maxDevices, activeDevices, status(ACTIVE/EXPIRED/REVOKED/SUSPENDED/
  UNACTIVATED), duration`.
- **AppNotification**: `id, title, body, priority(INFO/SUCCESS/WARNING/
  CRITICAL), category, createdAt, readAt?, relatedEntityId?`.

Example (matches the brief's JSON contract, kept adaptable via
`@JsonKey(includeIfNull: false)` and a tolerant `fromJson`):

```json
{
  "id": "setup_001",
  "symbol": "EURUSD",
  "timeframe": "M30",
  "direction": "BUY",
  "entry": 1.1824,
  "stopLoss": 1.1792,
  "takeProfits": [1.1888, 1.1940],
  "weeklyBias": "BULLISH",
  "dailyBias": "BULLISH",
  "session": "LONDON",
  "confluenceScore": 5,
  "confluenceMaximum": 6,
  "status": "PENDING",
  "detectedAt": "2026-09-21T10:30:00Z"
}
```

## 4. Service / repository interfaces

Widgets never see mock JSON directly — they depend on Riverpod providers that
expose a **repository**, which wraps a **service interface**. Only the service
layer knows whether it's mock or real.

```dart
abstract class AuthService {
  Future<AuthSession> login(String email, String password);
  Future<void> logout();
  Future<AuthSession?> restoreSession();
  Future<void> requestPasswordReset(String email);
}

abstract class ScannerService {
  Stream<List<ScannerSetup>> watchSetups({SetupStatus? status});
  Future<ScannerSetup> approve(String setupId, {String? note});
  Future<ScannerSetup> reject(String setupId, {required String reason});
  Future<ScannerSetup> update(ScannerSetup setup);
}

abstract class SignalService {
  Stream<List<Signal>> watchSignals({SignalStatus? status});
  Future<Signal> updateStatus(String signalId, SignalStatus status);
  Future<SignalPerformanceSummary> performanceSummary();
}

/// Publishing is decoupled from signal storage so new channels are additive.
abstract class SignalPublisherService {
  Future<void> publish(Signal signal, {required Set<PublishTarget> targets});
}
// Implementations (Phase 1, mock only): AppSignalPublisher,
// WhatsAppSignalPublisher (placeholder — logs intent, no HTTP calls),
// TelegramSignalPublisher (placeholder).

abstract class EAService {
  Stream<EAAccount> watchAccount(String accountId);
  Future<List<EAAccount>> listAccounts(); // OWNER/ADMIN view multiple
}
abstract class EAAccountService {
  Future<EAAccount> getAccount(String accountId);
}
abstract class EAControlService {
  Future<void> pauseTrading(String accountId);
  Future<void> resumeTrading(String accountId);
  Future<void> setRiskMode(String accountId, RiskMode mode);
  Future<void> setRiskPercentage(String accountId, double percentage);
  Future<void> disableNewEntries(String accountId);
  Future<void> emergencyStop(String accountId);
}

abstract class ClientService {
  Stream<List<ClientProfile>> watchClients();
  Future<void> setServiceAccess(String userId, PermissionSet permissions);
  Future<void> suspend(String userId);
  Future<void> reactivate(String userId);
}

abstract class LicenceService {
  Stream<List<Licence>> watchLicences({String? userId});
  Future<Licence> generate({
    required String userId,
    required String product,
    required LicenceDuration duration,
    required int maxDevices,
  });
  Future<Licence> revoke(String licenceId);
  Future<Licence> renew(String licenceId, LicenceDuration duration);
  Future<Licence> suspend(String licenceId);
}

abstract class NotificationService {
  Stream<List<AppNotification>> watchNotifications();
  Future<void> markRead(String notificationId);
  Future<void> markAllRead();
}
```

Migration path: `MockScannerService implements ScannerService` today;
`ApiScannerService implements ScannerService` later, swapped in a single
Riverpod provider override — no UI changes required. `Stream`-based reads let
mocks fake push updates (via `Stream.periodic`/`StreamController`) the same
shape a real backend (WebSocket/SSE/polling) would deliver.

**Mock service rule**: every `StreamController.broadcast(onListen: ...)` used
by a mock must defer its initial `add()` with `scheduleMicrotask(...)`
instead of calling it synchronously inside `onListen`. Adding synchronously
races Riverpod's own subscription setup for the first listener and can
leave that first value permanently undelivered — the provider then sits on
`AsyncLoading` forever with no error, which is easy to miss because a
screen's static text (headings, labels) still renders fine around the
stuck data. Found and fixed across every mock service during the Scanner
Approval Workflow milestone; keep new mocks consistent with it.

## 5. Role / permission model

Roles and permissions are **independent** axes, as required:

```dart
enum AppRole { owner, admin, trader, scannerClient, signalClient, eaClient, client, internal }

enum Permission {
  scannerAccess,
  scannerReview,      // approve/reject/edit pending setups
  signalsAccess,
  eaAccess,
  eaControl,          // pause/resume/risk changes/emergency stop
  clientAdmin,        // view/manage clients
  licenceAdmin,       // generate/revoke/renew licences
  systemAdmin,        // limited system controls (ADMIN-level, below OWNER)
}

class PermissionSet {
  final Set<Permission> granted;
  const PermissionSet(this.granted);
  bool has(Permission p) => granted.contains(p);
  static const PermissionSet none = PermissionSet({});
  static const PermissionSet owner = PermissionSet({/* all values */});
}
```

- A role has a **default** `PermissionSet` (e.g. `SCANNER_CLIENT` defaults to
  `{scannerAccess}`), but the *effective* permissions used everywhere in the
  app come from the user's own `PermissionSet` on `AuthUser`, not from a
  role→permission lookup table — this is what makes User A / User B in the
  brief (same role shape, different toggles) possible. `INTERNAL` has no
  default permissions at all; every grant is explicit. `CLIENT` (self-service
  sign-up, starting with the Create Account milestone) is the same: zero
  default permissions, every service entitlement (Scanner/Signals/EA) granted
  explicitly by an OWNER/ADMIN afterwards.
- `OWNER` is special-cased to always evaluate `has()` as `true` (full access),
  everyone else is checked against their stored `PermissionSet`.
- **UI enforcement**: a `PermissionGate(permission: ..., child: ...)` widget
  and a `ref.watch(hasPermissionProvider(Permission.x))` helper hide nav
  items, buttons and routes. `go_router` redirect logic also blocks direct
  navigation to a route the user lacks permission for (defense in depth, not
  just hidden buttons).
- **Explicit non-goal**: hiding a button is a UX convenience only. The
  architecture note in §9 states plainly that the mobile client is never the
  authority — a real backend must re-check permissions server-side once
  Phase 2 lands.

## 6. Navigation structure

`go_router` with a `ShellRoute` for the authenticated app shell
(bottom nav bar on phones, nav rail on tablets):

```
/splash                      (no shell)
/login                        (no shell)
/forgot-password              (no shell)
/register                     (no shell, placeholder only)

ShellRoute (authenticated)
  /dashboard                  — always visible
  /scanner                    — requires Permission.scannerAccess
    /scanner/setup/:id
  /signals                    — requires Permission.signalsAccess
  /ea                         — requires Permission.eaAccess
  /clients                    — requires Permission.clientAdmin
    /clients/:id
  /licences                   — requires Permission.licenceAdmin
  /notifications               — always visible
  /settings                    — always visible
    /settings/about
    /settings/profile
```

Only the primary 8 areas from the brief appear in the nav shell; anything a
user lacks permission for is filtered out of the bottom nav / rail entirely
(not just disabled), and its routes redirect to `/dashboard` if hit directly.

## 7. Design system — derived from `code-phantom-website`

Source of truth inspected: `tailwind.config.ts`, `globals.css`,
`lib/site-config.ts`, `components/ui/button.tsx`, `components/cards.tsx`,
`components/logo.tsx`, `public/logo.png`, `public/mark.png`.

### Colours (`AppColors`)

| Token | Hex | Website source |
|---|---|---|
| `phantomBlack` (base bg) | `#05070D` | `phantom-black`, body bg |
| `midnightNavy` (alt section bg) | `#09111F` | `midnight-navy` |
| `surface` (card bg) | `#0D1627` | `surface` |
| `surfaceRaised` (elevated card) | `#121D33` | `surface-raised` |
| `phantomPurple` (primary brand) | `#7C3AED` | `phantom-purple` |
| `cyberBlue` (secondary brand) | `#168BFF` | `cyber-blue` |
| `electricBlue` (tertiary accent) | `#00BFFF` | `electric-blue` |
| `metallicSilver` (borders/dividers) | `#C9CDD5` @ ~10–25% opacity | `metallic-silver` |
| `mutedText` | `#8792A5` | `muted-text` |
| `ghostWhite` (primary text) | `#F5F7FA` | `ghost-white` |
| `brandGradient` | `linear-gradient(135deg, #7C3AED 0%, #168BFF 60%, #00BFFF 100%)` | `phantom-gradient` |

Semantic colours (new — chosen to harmonize, not clash, with the palette
above; none of these override the brand colours):

| Semantic | Colour | Notes |
|---|---|---|
| success | `#22C55E` | standard green, desaturated slightly to sit next to electric blue |
| warning | `#F5A623` | amber, distinct from purple/blue family |
| error / SELL | `#EF4444` | |
| critical | `#FF3B5C` | reserved for EA emergency states, more saturated than error |
| BUY | `#22C55E` | matches success — BUY reads positive |
| SELL | `#EF4444` | matches error |
| online | `#22C55E` | |
| offline | `#6B7280` | neutral grey, not red — offline ≠ error |
| neutral | `metallicSilver` @ 60% | |

### Typography (`AppTypography`)

- Display / headings: **Space Grotesk** (`google_fonts` package, weights
  500/600/700) — matches `--font-display`.
- Body: **Inter** — matches `--font-sans`.
- Numeric/mono (prices, symbols, licence keys, timestamps): **JetBrains
  Mono** — matches `--font-mono`; used the same way the website uses it for
  session pills and confluence pipeline labels.

### Spacing & radius (`AppSpacing`, `AppRadius`)

- Spacing scale: 4/8/12/16/24/32/48 (matches Tailwind's default scale used
  across the site's `p-6`/`p-8`/`gap-6` patterns).
- Radius: cards `16px` (website's `rounded-2xl`), buttons/pills `999px`
  (fully rounded, matches `rounded-full` CTA buttons), small chips/badges
  `999px`, modals `20px` — "rounded but not excessively rounded" per brief,
  reserving full pill shape for buttons/chips only, not every surface.

### Shadows / glow (`AppShadows`)

- `glowPurple`: `0 0 40px rgba(124,58,237,0.25)` (matches `shadow-glow`).
- `glowBlue`: `0 0 40px rgba(22,139,255,0.25)` (matches `shadow-glow-blue`).
- Used sparingly — primary CTA buttons and the EA "online" status pulse only,
  not on every card (avoids the "neon" look the brief explicitly warns against).

### Components

- `PhantomButton`: primary (brand gradient fill), secondary (silver border,
  hover→cyber-blue border), ghost (text-only) — mirrors the website's three
  button variants exactly.
- `PhantomCard`: `surface` bg, 1px `metallicSilver@10%` border, `16px` radius,
  optional `card-hover`-style elevate-on-press for tappable cards.
- `StatusBadge` / `PhantomChip`: pill-shaped, colour-coded via semantic
  tokens (e.g. a `SetupStatus.pending` badge in warning colour, `SELL` chip
  in error colour).
- `PhantomModalSheet` / `ConfirmDialog`: dark surface, glass-panel style
  (`surface @ 60% + blur`) for destructive actions (emergency stop, revoke
  licence, suspend account).
- `BrandMark`: wraps `assets/brand/mark.png` (small/nav contexts) and
  `assets/brand/logo.png` (splash/login/about) — mirrors the website's own
  distinction between the cropped mark and the full lockup.

### Brand hierarchy in UI

- App bar / nav: small `mark.png` + "CODEPHANTOM" wordmark (purple
  "PHANTOM"), same treatment as the website navbar — never a large logo on
  every screen.
- Splash / Login / About / empty states: full `logo.png` lockup.
- Scanner section: subtitled "CPT Scanner · by CodePhantom Technologies".
- Signal cards: small watermark corner mark, reusable as a component so it
  can later be captured as a shareable image (WhatsApp/Telegram) without
  rebuilding the UI.
- EA section: brand colours retained but visual priority goes to status/
  metrics — no gradients or glow on data-dense EA rows, only on section
  headers/CTAs.

### Theming architecture

`AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppShadows` are
static const holders; `BrandAssets` centralises asset paths and wordmark
strings; `AppTheme.dark()` assembles a single `ThemeData` from them. Nothing
below `core/theme/` is referenced as a raw hex/asset path — every widget pulls
from these tokens, which is what makes future white-labelling (a different
CodePhantom-family brand skin) a matter of swapping `core/theme/` contents
only.

## 8. Security posture reflected in the architecture

- No API secrets, licence-generation secrets, or broker credentials appear
  anywhere in `lib/`. `MockLicenceService` visually formats keys like
  `CPT-SCN-7F4K-92MQ-X81P` purely for UI purposes and says so in a code
  comment — never treated as cryptographically meaningful.
- `core/storage/SecureStorage` wraps `flutter_secure_storage` for the (future)
  access/refresh tokens; nothing sensitive goes into `shared_preferences`.
- Permission checks exist in the UI layer for UX only; §5 states this
  explicitly in code comments on `PermissionGate` so nobody mistakes it for
  real authorization later.

## 9. Explicit seams for later phases

- `AuthService`, every module service, and `SignalPublisherService` are pure
  interfaces — Phase 2 adds `Dio`-based implementations behind the same
  contracts.
- `EAService`/`EAControlService` never simulate real order execution — mock
  data only moves numbers around, it never "trades."
- Push notifications: `NotificationService` is already stream-based; adding
  FCM later means feeding the same stream from a push payload instead of a
  mock timer, with no presentation-layer changes.

## 10. Milestones (git history)

1. Project foundation (pubspec, lint rules, folder skeleton, CI-friendly structure)
2. Theme + navigation shell
3. Auth + role/permission system
4. Scanner module
5. Signals module (+ publisher abstraction)
6. EA module
7. Clients + licences
8. Notifications + settings
9. Tests + README/docs polish

Each milestone lands as its own commit(s) on `main`.
