# CodePhantom Web / PWA

The CodePhantom Flutter app also runs in the browser. There is no separate
web application: Android and Web share the same code, services, models,
permissions, branding and backend.

| User | How they use CodePhantom |
|---|---|
| Android | The CodePhantom Android app (APK / release workflow). |
| iPhone / iPad | Safari → the CodePhantom web app → optionally *Share → Add to Home Screen*. |
| Desktop | Any modern browser (Chrome, Edge, Safari, Firefox) → the CodePhantom web app. |

All three use the same CodePhantom backend, accounts, permissions, Scanner
data, Signals and EA monitoring. The web app is **not** a native iOS app and
is not distributed through the App Store.

## Architecture

- Same Flutter code base (`lib/`), compiled with `flutter build web`
  (JavaScript + CanvasKit, bundled locally with `--no-web-resources-cdn`).
- Same real services in every connected environment: `ApiAuthService`,
  `ApiScannerService`, `ApiSignalService`, `ApiEAService`,
  `ApiCommerceService`. There are no web-only mocks.
- Web-specific code is isolated behind conditional imports:
  - `lib/core/storage/web_key_value_store_web.dart`: browser session storage.
  - `lib/core/platform/browser_location_web.dart`: removes auth-callback tokens
    from the address bar.
  - `lib/main.dart`: path URLs (`usePathUrlStrategy`) and auth-callback capture.
- Layout adapts by **window width**, not platform (`lib/core/layout/breakpoints.dart`):

  | Width | Navigation | Content |
  |---|---|---|
  | < 600 (phones, narrow windows) | bottom bar (icons only when > 5 items) | full width |
  | 600–1023 (tablets) | navigation rail with labels | full width |
  | ≥ 1024 (desktop) | extended navigation rail | centred, max 1200 px |

  Sign-in, registration and auth-callback pages are a centred 480 px column
  on wide screens.

## Supported platforms

| Platform | Status |
|---|---|
| Android app | Supported (unchanged). |
| Safari on iPhone / iPad (iOS/iPadOS 16.4+) | Supported in the browser and as a Home Screen web app. |
| Chrome / Edge (desktop, Android) | Supported; installable as an app. |
| Firefox (desktop) | Supported in the browser (Firefox does not install PWAs). |
| Native iOS app | Not built. The iOS project in `ios/` is not a release target. |

## Public web environment variables

Only **public** configuration reaches the web build. Everything compiled into
the web app can be read by anyone who opens it. Never pass service-role keys,
database URLs, payment secrets, peppers, webhook secrets or signing material.

| Variable | Required | Meaning |
|---|---|---|
| `APP_ENV` | yes | `staging` or `production` (`development`/`mock` for local work only). |
| `API_BASE_URL` | yes | `https://<backend host>/api/v1`. Staging builds must use the staging backend and production the production backend (`deploy/web/check_build_config.sh` refuses cross-wiring). |
| `AUTH_REDIRECT_URL` | no | `https://<web host>/auth/callback`. Defaults to the serving page's own origin + `/auth/callback`. |
| `SCANNER_REVIEW_ACTIONS` | no | `true` enables Scanner approve/reject/edit. Default `false` while the Scanner backtest is unvalidated. |

## Commands

```bash
# Local development against mock data (no backend)
flutter run -d chrome

# Local development against a local backend (http://localhost:8080)
flutter run -d chrome --dart-define=APP_ENV=development

# Staging build
flutter build web --release --no-web-resources-cdn \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://code-phantom-backend-staging.up.railway.app/api/v1

# Production build
flutter build web --release --no-web-resources-cdn \
  --dart-define=APP_ENV=production \
  --dart-define=API_BASE_URL=https://<production backend>/api/v1 \
  --dart-define=AUTH_REDIRECT_URL=https://<production web host>/auth/callback
```

Release builds contain no source maps (Flutter emits none by default; the
Dockerfile and CI also delete any `*.map`).

## Deploying to Railway

CodePhantom's backend already runs on Railway, so the web app runs there as a
second service built from this repository.

1. Railway → the CodePhantom project → **New service → GitHub repo →
   `code-phantom-App`**. Watch branch: `codephantom-app-dev-qn0faw` for
   staging.
2. Railway reads `railway.toml`: Docker build from `deploy/web/Dockerfile`,
   health check `/healthz`.
3. Service **Variables** (public values only):
   `APP_ENV=staging`,
   `API_BASE_URL=https://code-phantom-backend-staging.up.railway.app/api/v1`,
   optionally `AUTH_REDIRECT_URL=https://<web host>/auth/callback`.
4. **Settings → Networking → Generate domain** (or add a custom domain), e.g.
   `code-phantom-web-staging.up.railway.app`.
5. On the **backend** staging service:
   - `CORS_ALLOWED_ORIGINS=https://<web host>`: exact origin, no trailing slash.
   - Add `https://<web host>/auth/callback` to `AUTH_REDIRECT_ALLOWLIST`
     (keep `codephantom://auth-callback` for Android).
6. In **Supabase → Authentication → URL Configuration**, add
   `https://<web host>/auth/callback` to Redirect URLs.
7. Redeploy the backend, then open `https://<web host>/login`.

Production repeats these steps with a separate Railway service, the
production backend URL and the production web host. Production's
`CORS_ALLOWED_ORIGINS` and `AUTH_REDIRECT_ALLOWLIST` must contain only
production values; the backend refuses staging entries in production.

The container is nginx serving the build with:
- **SPA fallback:** every app path (`/login`, `/auth/callback`,
  `/scanner/setup/42`) returns `index.html`, so refreshes and pasted links
  never 404. Missing asset files still return a real 404.
- **Security headers:** a strict Content-Security-Policy (script only from
  the app's own origin, API calls only to `API_BASE_URL`'s origin),
  `frame-ancestors 'none'`, HSTS, `nosniff`, a referrer policy and a
  permissions policy.
- **`Cache-Control: no-cache`** on everything, so a deploy is picked up on the
  next load.

`.github/workflows/build-web-staging.yml` builds the same staging bundle in CI
(analyze, test, config check, build, no source maps) and uploads it as an
artifact. `flutter-ci.yml` also checks that the web target compiles.

## CORS

The backend accepts browser requests only from the exact origins in
`CORS_ALLOWED_ORIGINS`: no wildcard, HTTPS only, no path or trailing slash
in deployed tiers. The web app sends `Authorization`, `Content-Type` and
`X-Request-Id`; methods GET, POST, PUT, PATCH and DELETE are allowed.
Credentialed (cookie) CORS is off because the API authenticates only with the
bearer header. Android, the scanner and the EA send no `Origin` and are
unaffected.

## Authentication on the web

| Flow | Web behaviour |
|---|---|
| Registration | `POST /auth/register` with `redirect_to = https://<web host>/auth/callback`. |
| Email verification | The email link opens `/auth/callback#…type=signup`; the page confirms verification and sends the user to sign in. |
| Login / logout | Same endpoints as Android. Logout calls the backend, then deletes the stored session. |
| Session restoration | On load (including a refresh or a pasted deep link) the stored session is restored, refreshed if expired, and `/me` is re-read. The user lands on the page they asked for. |
| Access-token refresh | The same single-flight refresh as Android (`ApiAuthService`). |
| Password reset | *Forgot password* → email → `/auth/callback#…type=recovery` → *Choose a new password*. |
| Expired / invalid session | Refresh failure or 401 clears the session and returns to `/login`. |

Callback handling (`lib/main.dart`): the callback URL is captured in memory
before the app starts, and the address bar is immediately replaced with the
bare `/auth/callback` (`history.replaceState`). Tokens therefore never remain
in the URL, in browser history (Back does not restore them), in storage or in
logs. The captured values are used once and then discarded; the signup and
recovery links' own tokens are never saved as a session.

Mobile keeps `codephantom://auth-callback`; the browser never uses it.

## Token storage (web security trade-off)

On Android, tokens live in `flutter_secure_storage` (Keystore-backed
EncryptedSharedPreferences). A browser has no equivalent:

- `flutter_secure_storage` on the web only encrypts with an AES key it stores
  in the same `localStorage`, which adds no protection. Its `deleteAll()` also
  clears the whole origin's storage. The web build therefore does **not** use
  it.
- The web build stores the session (access token, refresh token, expiry) in
  `localStorage` under `codephantom.*` keys, so the installed PWA stays
  signed in across launches. Logout deletes exactly those keys.
- Any script running on the web app's origin could read them (XSS). The
  mitigations are:
  - a strict CSP that allows no inline script, no third-party scripts and no
    API calls except to the configured backend;
  - no HTML rendering of user content;
  - short-lived Supabase access tokens with rotating refresh tokens;
  - server-side authorization on every request.
- An HttpOnly-cookie session would remove JavaScript access to the refresh
  token. It needs backend changes (a cookie endpoint, CSRF protection,
  credentialed CORS) and is the recommended hardening step before handling
  high-value operations in the browser.

## PWA behaviour

- `web/manifest.json` sets:
  - name and short name "CodePhantom", id and scope `/`;
  - `display: standalone`, `orientation: any`;
  - theme and background colour `#05070D`;
  - 192/512 icons plus maskable icons, all from the CodePhantom mark.
- `web/index.html` provides:
  - CodePhantom title and description;
  - Apple Home Screen metadata (`apple-mobile-web-app-*`, a 180 px
    `apple-touch-icon`);
  - `theme-color`, a favicon and `noindex`;
  - a branded loading screen until Flutter's first frame.
- Service worker (`web/cp_sw.js`):
  - Handles top-level page navigations only: network first, and a branded
    offline page (`web/offline.html`) when there is no connection.
  - Never caches or intercepts API, auth or asset requests. It cannot serve
    stale account data, store tokens or pin an old build.
- Flutter 3.47's own `flutter_service_worker.js` is a self-removing stub.
  CodePhantom does not use it.
- Chrome and Edge offer "Install CodePhantom". Safari offers *Share → Add to
  Home Screen*, which opens full-screen with the CodePhantom icon.

## Android / Web differences

| Area | Android | Web |
|---|---|---|
| Auth email return | `codephantom://auth-callback` | `https://<web host>/auth/callback` |
| Token storage | Keystore-backed secure storage | origin `localStorage` (see above) |
| URLs | in-app routes | real browser URLs; refresh, Back/Forward and deep links work |
| Checkout (when enabled) | opens the provider in the external browser | opens the provider in a new tab |
| Push notifications | not implemented | not implemented |
| Offline | app shell always available | offline page only |

## Known limitations

- The web build can't be tested against staging from the development sandbox
  used for this work, because the staging hosts are not reachable from it.
  Web ↔ staging integration still needs checking in a real browser after
  deployment (owner action).
- Safari (WebKit) was checked at iPhone viewport sizes in Chromium, not in
  real WebKit. Test on a real iPhone after deployment.
- No push notifications on the web. Notifications, Clients and Licences are
  still mock-backed in every environment (see `CURRENT_STATE.md`).
- Tokens in browser storage (see *Token storage*).
- WebAssembly (`--wasm`) builds are not enabled; the JavaScript build is used.

## Security checklist for web releases

- [ ] `APP_ENV`/`API_BASE_URL` match the target tier (the build refuses mismatches).
- [ ] No secret values in the Railway web service variables.
- [ ] Backend `CORS_ALLOWED_ORIGINS` lists exactly this web origin.
- [ ] Backend `AUTH_REDIRECT_ALLOWLIST` and Supabase Redirect URLs include `https://<web host>/auth/callback`.
- [ ] `https://<web host>/healthz` returns `ok`; `/scanner` refresh returns the app, not a 404.
- [ ] Response headers include the CSP and HSTS.
- [ ] Settings → Diagnostics shows the expected environment and API URL.
