# CodePhantom security & release-readiness audit: 2026-09-27

**Scope:**

| Repository | Branch audited |
|---|---|
| code-phantom-App | `feature/web-pwa` |
| code-phantom-backend | `feature/web-pwa-cors` |
| CPT-Scanner | `main` |
| code-phantom-ea | `main` and the unmerged `feature/infrastructure-sprint` bridge |
| code-phantom-website | `main` |

**Method:**
- Code review.
- Full-history secret scanning (gitleaks with redaction, plus targeted patterns: env files, keystores, JWT-shaped keys, credentialed database URLs, Paystack/AWS/GitHub tokens).
- `npm audit` for Node dependencies.
- Inspection of compiled web bundles.
- Executable tests: Flutter, vitest, real PostgreSQL 16, headless Chromium against the production nginx configuration.

**Not reachable from the audit environment:** the deployed staging hosts, Supabase dashboards and advisors, and real Safari/WebKit. Nothing here was verified against a live deployment.

No secret values are recorded in this document.

## Summary

| Severity | Found | Fixed in this audit | Open |
|---|---|---|---|
| Critical | 0 (1 advisory group rated critical by npm, reported as High WEB-1 after mitigation) | – | – |
| High | 2 (EA-CMD, WEB-1) | 1 | 1 (WEB-1, partly mitigated) |
| Medium | 6 | 5 | 1 (APP-TOKEN, accepted trade-off) |
| Low | 8 | 7 | 1 (BE-RL, carried over) |
| Informational | 2 | – | 2 |

## 1. Secret exposure

**No issue found.** Full Git history of all five repositories was scanned.
- No `.env` files, keystores, `key.properties`, private keys, Supabase
  service-role keys or other JWTs were found.
- No credentialed database URLs, Paystack secret keys, webhook secrets,
  peppers, or AWS/GitHub tokens were found.
- **ROTATION REQUIRED: none.**

Informational:
- **INFO-1:** gitleaks flags three values in
  `lib/features/licences/data/mock_licence_service.dart` (App). They are
  fixture licence keys in the in-memory demo service's seed data and
  unlock nothing.
- **INFO-2:** the compiled web bundle contains the mock demo accounts'
  e-mail addresses and passwords (the login screen's mock-mode hint). They
  only work against the in-memory `MockAuthService`. Staging and production
  builds cannot select mock mode because `APP_ENV` is compiled in.
  **Owner action:** confirm no real backend account uses those passwords.
- The staging web bundle contains only the public staging API URL. It has
  no Supabase keys, peppers, payment keys or signing material, and no
  source maps.

## 2. Frontend / web security (App)

| ID | Severity | Status | Finding |
|---|---|---|---|
| APP-STORE | Medium | **Fixed** | On the web, `flutter_secure_storage` "encrypts" with an AES key stored beside the ciphertext in the same `localStorage` (no protection), and its `deleteAll` clears the whole origin's storage. The web build now uses an honest, namespaced browser store and only ever deletes its own keys. |
| APP-CALLBACK | Medium | **Fixed** | A browser auth callback carries Supabase tokens in the URL fragment. It is now captured in memory before the app starts and removed from the address bar and history (`history.replaceState`). Tested in Chromium: the token is absent from the URL, from Back navigation and from storage. |
| APP-SESSION | Low (reliability) | **Fixed** | Access tokens were refreshed only at startup. A long-lived tab or PWA then got 401s shown as "Invalid email or password" and was never refreshed or signed out. Requests now refresh before expiry and retry once after a 401 (single-flight); a rejected refresh clears the session and returns to sign-in. |
| APP-REDIRECT | Low | **Fixed** | The new deep-link return (`/login?from=…`) accepts only in-app paths. Absolute, protocol-relative, `javascript:` and auth-page targets are rejected (tested). |
| APP-STAGING-ID | Low | **Fixed** | The Android staging APK workflow compiled `APP_ENV=production` while pointing at staging, so the device diagnostics misreported the environment. |
| APP-TOKEN | Medium | **Open (accepted trade-off)** | Web session tokens live in `localStorage`, readable by any script running on the web origin. Mitigations: a strict CSP (no inline or third-party script, API calls only to the configured backend), no HTML rendering of user content, and server-side authorization on every call. Recommended hardening: an HttpOnly-cookie session for the web (needs a backend cookie endpoint, CSRF protection and credentialed CORS). |

**No issue found:**
- **Route guards:** `permissionForPath` still gates `/scanner`, `/signals`, `/ea`, `/clients` and `/licences`. Deep links and refreshes pass through the same redirect guard (tested). Guards are UX only; the backend enforces every permission.
- **Permission gates:** Scanner review controls appear only when actions are enabled and the user holds `scanner.review`. EA controls throw before any network call.
- **Diagnostics:** show the build, environment and public API URL only, never tokens (existing tests).
- **Logging:** the only `debugPrint` is the startup timing trace (labels only).
- **XSS:** no HTML/webview rendering. External links (checkout, subscription management) must be HTTPS before `launchUrl`.
- **Source maps and defaults:** not published. The default `APP_ENV` is `mock` (no backend); `SCANNER_REVIEW_ACTIONS` defaults to off.
- **Web hosting:** nginx sends a CSP limited to the API origin, `frame-ancestors 'none'`, HSTS, `nosniff`, a referrer policy and a permissions policy (verified with curl and Chromium; no CSP violations while signed in or out).

## 3. Backend security

| ID | Severity | Status | Finding |
|---|---|---|---|
| EA-CMD | **High** | **Fixed** | `POST /api/v1/ea/accounts/:id/commands` let any account **owner** (including ordinary clients) queue EA commands (`RESUME_TRADING`, risk changes, …). Nothing checked the compliance-gated `ea.remote_commands` flag, which is off. Commands are delivered to an EA only while that flag is on, so every queued command would have gone out the moment it was enabled. Queuing now requires the flag (tested: owner and staff both get 403, and no row is written). |
| EA-FIELDS | Medium | **Fixed** | `PATCH /api/v1/ea/accounts/:id` let an owner change staff-controlled fields: `trading_enabled`, `risk_mode`, `risk_percentage` and `status`. An owner could therefore lift a staff suspension. RLS already blocked this for direct database writes; the API did not. Owners may now only rename their account (tested). |
| WA-HOOK | Low | **Fixed** | The WhatsApp delivery webhook skipped signature checks whenever `WHATSAPP_APP_SECRET` was unset, including in staging/production with a non-Meta provider. Deployed tiers now fail closed (tested). |
| CORS-FMT | Low | **Fixed** | Deployed tiers now also refuse CORS origins with a path or trailing slash (they never match). Production refuses staging web origins and staging auth redirects. Credentialed CORS is off (bearer-token API, no cookies). |
| BE-RL | Low | Open (carried over) | Rate limiting is per instance, in memory. Add a shared store before running more than one API instance. |

**No issue found:**
- **Authentication:** Supabase token verification on every protected route; profile status checked.
- **Authorization:** every staff/admin route uses `requirePermission`. Self-service routes use `req.user.id`, never a client-supplied user id. The only client-supplied `user_id` (`POST /ea/accounts`) is honoured only for `ea.control` staff.
- **Input validation:** zod schemas, strict where the contract is closed.
- **SQL:** all values parameterized. Dynamic column lists come only from zod-validated keys.
- **Errors:** 5xx responses return a generic message with a request id, with no stack traces.
- **Log redaction:** covers `authorization`, cookies, passwords and keys.
- **Licence/activation keys:** peppered hashes, atomic redemption (existing tests).
- **CSRF:** not applicable to the API (bearer header, no cookies, credentialed CORS off).
- **Dependencies:** `npm audit --omit=dev` reports 0 vulnerabilities.

## 4. Payment security

| ID | Severity | Status | Finding |
|---|---|---|---|
| PAY-REFUND | Medium | **Fixed** | A refund or dispute event was checked against the checkout price. A partial refund (refund amount ≠ price) raised `PAYMENT_AMOUNT_MISMATCH`, rolled back and was retried by the provider forever, so the entitlement was never revoked. Now only payments are price-checked (real-Postgres test, which fails on the old code). |
| PAY-MODE | Medium | **Fixed** | Nothing stopped a live Paystack key or live PayPal on staging, or a test key or sandbox PayPal in production. Deployed tiers now refuse crossed credentials (tested). |

**Verified with no issue:**
- **Keys server-only:** Paystack, PayPal, Skrill and Binance Pay secrets exist only in backend configuration. The App and website call the backend, and the checked bundles contain no payment keys.
- **Server-authoritative prices:** checkout takes only `plan_code`, `offer_code` and `provider`. The amount comes from the enabled, published plan and the validated offer. The client cannot submit a price.
- **Underpayment:** a paid event applies only to a purchase the server created at checkout (unknown references are ignored). The paid amount and currency must equal the stored checkout values, and an underpaid charge grants nothing (tested).
- **Webhook signatures:**
  - Paystack: HMAC-SHA512 over the raw body, constant-time compare.
  - PayPal: API verification.
  - Binance Pay: signature check.
  - Skrill: MD5 status signature (provider-defined).
  - Mock: HMAC with a 5-minute replay window.
  - All verify before parsing.
- **Idempotency:** `payment_events` is unique on (provider, event id). Duplicates are no-ops, and entitlement grants are `ON CONFLICT DO NOTHING`.
- **Entitlements:** only `purchase.paid` grants. Refunds and disputes revoke the purchase's entitlements.
- **Disabled by default:** `PAYMENT_PROVIDER=none`, `commerce.checkout` off and staff-only, and every plan ships disabled with no price. No live credentials or transactions were introduced.

## 5. Supabase / database

**No new issue found.** Previous findings are recorded in the backend's
`docs/SECURITY_REVIEW_2026-09.md`, and the real-Postgres suite (85 tests)
passes:
- RLS is on for every public table. Every SECURITY DEFINER function pins
  `search_path`, and helper functions are not executable by `anon`.
- Users cannot change their own status, protected flag, roles or
  permissions. Role and permission writes require `admin.system`.
- `account_entitlements`, `purchases`, `payment_events`, `trials`,
  `offer_redemptions` and `core_licences` have **select-only** policies for
  users (own rows, or staff with the matching permission), so users cannot
  grant themselves licences or entitlements.
- Users cannot read other users' profiles, licences, devices or licence key
  hashes.
- Idempotency and security constraints exist: `signals.source_setup_id`
  unique; `payment_events (provider, provider_event_id)` unique; scanner
  setups unique per publisher `external_id`; `purchases (provider,
  provider_reference)` unique.

**Owner action:** run Supabase **Security Advisor** and **Performance
Advisor** on staging and production after applying migrations. They were not
reachable from the audit environment.

## 6. Scanner (CPT-Scanner)

**No issue found:**
- **No execution capability:** no `order_send`/`TRADE_ACTION`, no broker
  login. MT5 is used read-only for closed candles.
- **Credentials:** the integration key and API URL come from environment
  variables, are never printed, and HTTPS is required (except localhost).
  `.env*`, credentials files, `state/live/` and broker alias files are
  git-ignored.
- **Data crossing into the backend:**
  - The payload matches the backend's strict schema (tested for all 19
    symbols).
  - Timestamps are RFC 3339 UTC.
  - Delivery is idempotent on the deterministic `external_id`, with
    dead-lettering on conflict and no back-publishing of closed setups.
  - Journal and receipt writes are fsynced (fixed in the earlier pipeline
    work).

Fixed:
- **CI-1** (Low): `tests.yml` had no `permissions:` block, so the token
  inherited the repository default. It now uses a read-only token (branch
  `ci/least-privilege-token`).

## 7. EA (code-phantom-ea)

**No issue found:**
- `main` is Python research and backtesting code: no broker credentials,
  no order execution, no network calls.
- The platform bridge (unmerged `feature/infrastructure-sprint`):
  - reads its key from the environment or a key file and never logs it or
    shows it in `repr`;
  - parses commands into a fixed allow-list as data only, with **no
    executor**;
  - honours the backend's `commands_enabled=false`.
- The App's EA controls are paused (they throw before any network call).
  The backend now also refuses to queue commands while `ea.remote_commands`
  is off (EA-CMD above).

## 8. Website (code-phantom-website)

| ID | Severity | Status | Finding |
|---|---|---|---|
| WEB-1 | **High** | **Partly mitigated, open** | Next.js 14.2.35 is affected by 23 published advisories fixed only in 15.5.24+/16 (npm rates the group critical). The most severe, unauthenticated RCE in the Image Optimization API when AVIF is served, applied directly because the config enabled AVIF. **Mitigated** on branch `security/release-audit-hardening` by serving images unoptimized, which removes that endpoint and several DoS advisories. Remaining: RSC denial-of-service and cache-poisoning advisories. **Remediation: upgrade to Next.js ≥ 15.5.24.** This is a major version: the portal's `cookies()` becomes async; regression-test the portal and checkout. |
| WEB-2 | Low | **Fixed** | Portal API routes use cookie sessions (HttpOnly, SameSite=Lax) with no Origin check. The new `middleware.ts` refuses state-changing portal requests whose `Origin`/`Sec-Fetch-Site` is not this site. This adds defence in depth for sibling subdomains and browsers without SameSite (tested). |

**No issue found:**
- **Environment variables:** only `NEXT_PUBLIC_SITE_URL`, the WhatsApp
  invite URL and Android release metadata are public, all intentionally.
- **Server-only values:** `CODEPHANTOM_API_URL` (HTTPS enforced) and the
  optional LLM key are not public, and the built client bundles contain
  neither.
- **Routes:** no admin or debug routes.
- **Portal forms:** the backend validates all input; portal cookies are
  HttpOnly, SameSite=Lax and Secure in production.

## 9. Dependencies and CI/CD

| Area | Result |
|---|---|
| backend `npm audit --omit=dev` | 0 vulnerabilities |
| website `npm audit --omit=dev` | `next` (WEB-1) and its bundled `postcss`; both fixed by the Next.js upgrade |
| App (pub) | no advisories reported by `flutter pub get`. `flutter_secure_storage_web` 1.2.1 uses deprecated `dart:html` (not a vulnerability; no longer used on the web) |
| Scanner | Python standard library only |
| GitHub Actions | All workflows now declare `permissions:` (App `build-android-debug.yml` and Scanner `tests.yml` fixed, **CI-1**). No `pull_request_target`. Workflow inputs pass through `env:`, not inline shell. |
| Release signing | The Android release keystore and passwords are only available through the `staging`/`production` GitHub Environments. They are written to disk for the build and deleted in an `always()` step. Tag pushes build `APP_ENV=production`, manual runs `APP_ENV=staging`. |
| Build artefacts | Web and APK artefacts are retained for 7 days. The web bundle ships no source maps (CI asserts this). |

## 10. Release readiness: environment separation

| Concern | State |
|---|---|
| Backend | Staging and production are separate deployments. Web and Android builds refuse or flag mismatches: web `check_build_config.sh` refuses production→staging API and staging→non-staging API. Android diagnostics compare the build's environment with the backend's `/health` report. |
| Database | Each backend tier has its own `SUPABASE_*` (documented in the backend's `docs/ENVIRONMENTS.md`). |
| Auth redirects | Per-tier `AUTH_REDIRECT_ALLOWLIST`; production refuses staging and local entries. |
| CORS | Per-tier exact origins; production refuses staging origins. |
| Payments | Per-tier keys; staging refuses live credentials and production refuses test/sandbox credentials. |
| Environment identity | App → Settings → Diagnostics shows environment and API URL; the backend `/health` reports `env`; the web build's environment is compiled in. |

## RELEASE BLOCKERS

Only genuine security or reliability problems that should stop a deployment
are listed here.

1. **Website production deploy: WEB-1 (Next.js advisories).** Upgrade the
   website to Next.js ≥ 15.5.24 before the website and portal go to
   production. The Image Optimizer mitigation (branch
   `security/release-audit-hardening`) must be merged in the meantime.
   Staging may proceed with the mitigation.
2. **Backend (any tier): merge the audit fixes.** Deploy only a backend
   that includes branch `feature/web-pwa-cors`: the EA-CMD/EA-FIELDS
   authorization fixes, PAY-REFUND and PAY-MODE. Deploying the current
   default branch leaves EA-CMD open.

No blocker applies to the CodePhantom Web/PWA or Android app builds
themselves.

Not blockers, but required before production:
- the owner actions above (Supabase advisors, confirming no demo passwords
  on real accounts);
- the web deployment steps in `docs/WEB.md`.
