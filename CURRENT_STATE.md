# CodePhantom: current state (2026-09-27)

What exists in code, what is deployed, and what still needs the owner.
**Code-ready** means merged-quality code with passing tests. **Deployed** and
**live-verified** are stated separately. Nothing in this release was
verified against a live deployment from the development environment.

## Platforms

| User | Path | State |
|---|---|---|
| Android | CodePhantom Android app | Code-ready; CI builds the APK (Flutter CI). Signed release workflow unchanged. |
| iPhone / iPad | Safari → CodePhantom web app → optional *Add to Home Screen* | Code-ready (branch `feature/web-pwa`). **Not deployed**; the Railway web service needs creating (owner). Checked at iPhone/iPad viewport sizes in Chromium, not in real Safari. |
| Desktop | Browser → CodePhantom web app | Code-ready, same web build. **Not deployed.** |

All three use the same backend, accounts, permissions and real services.
See `docs/WEB.md`.

## Modules

Environment = development/staging/production builds. Mock mode is for tests
and demos only.

| Module / screen | Status | Notes |
|---|---|---|
| Sign in, logout, registration, email verification, password reset | **REAL BACKEND** | Web uses `https://<web host>/auth/callback`; Android uses `codephantom://auth-callback`. |
| Session restore / token refresh / expiry | **REAL BACKEND** | Refresh before expiry and after a 401; expiry returns to sign-in. |
| Scanner: list, detail, filters | **REAL BACKEND** | Clients see approved setups only (server-enforced). |
| Scanner: approve / reject / edit | **DISABLED** (build flag) | `SCANNER_REVIEW_ACTIONS=true` enables the real backend calls once the Scanner backtest is validated (**OWNER ACTION**). The backend requires `scanner.review` regardless. |
| Signals: list, performance | **REAL BACKEND** | |
| Signals: publish / status changes | **DISABLED** | Paused until backtests pass. Signals are created only by the backend approval transaction. |
| EA monitoring (accounts, status) | **REAL BACKEND** (read-only) | |
| EA controls (pause/resume/risk/commands) | **DISABLED** | The App throws before any network call. The backend refuses to queue commands while `ea.remote_commands` is off (after merging backend `feature/web-pwa-cors`). |
| Payments / billing | **NOT IN v1 APP** | Native store/checkout UI was deliberately removed for the first public release. Existing backend commerce remains disabled for a later version. |
| Dashboard | Mixed | Scanner/Signals/EA tiles are real; client and notification tiles are mock. |
| Notifications | **MOCK** | No backend service in the app yet. |
| Clients (admin) | **MOCK** | |
| Licences (admin) | **MOCK** | |
| Settings → Profile, About, Diagnostics | **REAL** | Diagnostics shows environment, public API URL and a backend health check. |
| Signal publishing channels (App/WhatsApp/Telegram publishers) | **MOCK**, unused by any screen | |

## Branches and pull requests (not merged)

| Repo | Branch | PR | Contents |
|---|---|---|---|
| code-phantom-App | `feature/web-pwa` | #7 (draft) | Web/PWA, staging-audit integration, responsive UI, web auth, session refresh, Railway web deployment, docs, this file, `docs/SECURITY_AUDIT.md`. Contains all of PR #6 (staging connection audit), which is now closed as superseded. |
| code-phantom-backend | `feature/web-pwa-cors` | #14 (draft) | Web CORS rules; security fixes EA-CMD, EA-FIELDS, PAY-REFUND, PAY-MODE, WA-HOOK. **Merge before any backend deploy.** |
| code-phantom-website | `security/release-audit-hardening` | #8 (draft) | Image Optimizer mitigation (WEB-1) and portal Origin check. |
| code-phantom-website | `security/nextjs-15-upgrade` | #9 (draft, stacked on #8) | Next.js 15.5.26 + React 19; `npm audit` 0 vulnerabilities; closes WEB-1. |
| CPT-Scanner | `ci/least-privilege-token` | #4 (draft) | Read-only CI token. |

## Tests (on the branches above, in the development environment)

| Check | Result |
|---|---|
| App `flutter analyze` | no issues |
| App `flutter test` | 239 passing |
| App `flutter build web` (staging config) | succeeds |
| App Android | Dart AOT compile for the Android target succeeds locally. GitHub Flutter CI (including `flutter build apk --debug`) passed on `4532ea4`. |
| App web in headless Chromium | boot, no CSP violations, deep links, callback token removal, service worker, signed-in navigation/refresh/Back at iPhone and desktop sizes |
| backend `vitest` / real Postgres / `tsc` | 158 / 85 passing; clean. GitHub CI green on PR #14. |
| website `npm test` / lint / `tsc` / `next build` | passing |
| Scanner unit tests | 319 passing (unchanged by this release) |

## Owner actions (in order)

1. Review and merge backend PR #14, then deploy the backend to staging.
2. Review and merge App PR #7.
3. Create the Railway web staging service (`docs/WEB.md`, "Deploying to
   Railway"). Then set:
   - backend `CORS_ALLOWED_ORIGINS`;
   - `AUTH_REDIRECT_ALLOWLIST` with the web `/auth/callback`;
   - Supabase Redirect URLs.
4. On a real iPhone (Safari) and a desktop browser, go through the checklist
   at the end of `docs/WEB.md`:
   - sign in, sign out, refresh, reset password;
   - Scanner, Signals, EA;
   - Add to Home Screen.
5. Merge Scanner PR #4 and website PR #8, then website PR #9 (Next.js 15).
   After #8 merges, retarget #9 to `main` if GitHub hasn't done it
   automatically. Vercel must build with Node.js ≥ 18.18 (20 recommended).
6. Run the Supabase Security and Performance Advisors on staging and
   production.
7. Confirm no real account uses a mock demo password (`docs/SECURITY_AUDIT.md`
   INFO-2).
8. When the Scanner backtest is validated, build with
   `SCANNER_REVIEW_ACTIONS=true`. `ea.remote_commands` stays off until
   separately approved. Payments are intentionally absent from the v1 app.

## Security audit outcome

See `docs/SECURITY_AUDIT.md`:
- No secrets found in any repository or its history; no rotation required.
- Fixed: 1 High (EA-CMD), 5 Medium, 7 Low.
- WEB-1 (High, Next.js advisories): fixed by website PR #9 (pending merge).
- Open:
  - APP-TOKEN (Medium, accepted web token-storage trade-off, documented);
  - BE-RL (Low, carried over).
- Release blockers:
  - website production waits on PR #9 (WEB-1);
  - any backend deploy must include the `feature/web-pwa-cors` fixes.

## Recommended continuation order

1. Deploy backend `feature/web-pwa-cors` and the web app to staging; verify
   on real devices (owner actions 1–4).
2. Merge the website Next.js 15 upgrade (PR #9) after #8, and check the
   Vercel preview's portal sign-in and checkout against staging.
3. Web session hardening: HttpOnly-cookie session for the web (APP-TOKEN).
4. Replace the mock Notifications, Clients and Licences services with real
   backend services in a later admin-focused release; do not expose unfinished
   payment functionality in v1.
5. Shared rate-limit store before scaling the API horizontally (BE-RL).
