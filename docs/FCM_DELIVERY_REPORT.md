# FCM staging delivery evidence

Android package: `com.codephantom.app`. Firebase project: `codephantom-technologies`.
Implementation tested: `dfd8c42d85450c790b991eec70467511642d0bbb`.
Backend tested: `667e126f0ad9e066828c17ae41a18fe4288b0a3b`.

Draft App PR [19](https://github.com/st10490392/code-phantom-App/pull/19) is stacked on PR 18. Draft Backend PR [27](https://github.com/st10490392/code-phantom-backend/pull/27) is stacked on PR 26. Their existing dependencies remain intact; neither is merged or deployed.

## Verified builds and tests

- [Final Flutter CI](https://github.com/st10490392/code-phantom-App/actions/runs/37820857214): clean analysis, 255 Flutter tests, four Android configuration tests, three service-worker tests, Android/PWA builds and iOS build passed.
- [Signed staging build](https://github.com/st10490392/code-phantom-App/actions/runs/37820887617): 255 Flutter tests passed; Firebase configuration decoded and validated from the staging secret; owner release signing verified with apksigner. Firebase and signing temporary files were cleaned up. No release was published.
- [Backend CI](https://github.com/st10490392/code-phantom-backend/actions/runs/37818138363): 169 unit/integration tests and 113 real PostgreSQL tests passed, including authorization, entitlement revocation, private token storage and outbox tests. Typecheck, build and Docker build passed. Four existing lint warnings remain.

[Download signed staging APK/AAB bundle](https://github.com/st10490392/code-phantom-App/actions/runs/37820887617/artifacts/11568874713). Artifact `codephantom-android-staging-13` expires November 7, 2026. Preserve it securely before expiration.

| File | SHA256 |
| --- | --- |
| app-release.apk | `c6cb5dd73d731a0dd2db24d9d2b27e80ece4c5782458f54e5ea511dabc7a5d1d` |
| app-release.aab | `46a6efb3a3689fcb0c1d78054f3782d9d93fd9319d19ab45a97e93b0a8131027` |
| artifact ZIP | `833aa5218ef0faa2f96365d8ddb2978714bcac170cb0926d8606656d7f5d796a` |

The APK targets `https://code-phantom-backend-staging.up.railway.app/api/v1` with push enabled. Its source is the tested implementation SHA above. The owner signing certificate was verified, not a debug certificate. A later documentation-only delivery commit does not change the built implementation.

## Implementation and limits

Android initializes Firebase from the ignored native configuration, requests notification permission through user opt-in, registers/refreshes tokens, disables auto-init and removes tokens on logout. Foreground messages use neutral content; background notification payloads use the operating system without generating a duplicate local notification. The high-importance channel is `codephantom_signals`. UUID-validated deep links fetch the signal through authenticated backend authorization; notifications never grant signal access or disclose strategy identities.

The backend uses private registrations and its existing entitled push outbox, rechecking grants before delivery. Event/delivery uniqueness, stable notification tags and bounded persisted client event IDs suppress duplicates. Sending and recording acceptance cannot be atomic: a crash can produce at-least-once retries. FCM acceptance is not a delivery receipt. Offline logout requires connectivity for server/SDK revocation, and already accepted OS notifications cannot be recalled.

Web registration, VAPID configuration generation, secure same-origin service-worker clicks and WEB platform backend support are implemented and tested. The default PWA build has push disabled until the owner's public Firebase Web configuration is supplied. Installed iPhone Home Screen PWA and desktop browser delivery have not been physically verified.

Read-only checks confirmed the current staging `/health` and `/ready` returned HTTP 200 with staging identity. This does not establish that these draft changes are deployed or that FCM delivery is configured.

## Remaining owner actions

1. Approve staging migration/deployment separately. Review backups and the existing Backend PR 25 → 26 → 27 migration chain, including `20261008173502_web_push_registrations.sql`, before applying anything. This additive platform constraint migration preserves registrations and signal history. Follow the rollback instructions in the linked runbook; retain audit records.
2. Enable Firebase Cloud Messaging HTTP v1 for the project and create a dedicated server sender identity with the required message-send permission. Configure Railway staging `PUSH_PROVIDER=fcm`, `PUSH_FCM_PROJECT_ID=codephantom-technologies`, `PUSH_FCM_CLIENT_EMAIL` and `PUSH_FCM_PRIVATE_KEY`. Store the private key only in server secrets, never in Git, APKs, public variables or logs. GitHub's Android Firebase and signing secrets were already successfully exercised.
3. For Web Push, create the Firebase Web app and public VAPID key, configure the public Web values and explicit push opt-in described in the runbook, and review staging HTTPS/CSP/CORS. Android JSON cannot substitute for Web app configuration. iPhone requires iOS 16.4+ and an installed Home Screen PWA with permission requested from a user gesture.
4. Use an entitled test account and physical Android device. Check permission denied/granted, foreground, background, locked phone, cold-start signal navigation, refresh/rotation, logout, revoked entitlements and duplicate event retries. Record UTC timestamps, event IDs and device observations. Repeat supported desktop browser and installed iPhone PWA cases. Android force-stop suppresses delivery until reopening. No physical delivery receipt exists yet.

Exact configuration, build commands, secure credential handling, migration/rollback order and physical acceptance checklist: [FCM_STAGING_ACCEPTANCE.md](FCM_STAGING_ACCEPTANCE.md). Backend configuration: `docs/FCM_WEB_STAGING.md` in Backend PR 27.

No shared database migration, deployment, merge, broker order, scanner process/state change or historical signal deletion occurred. No service-account private key or environment-specific Firebase configuration was committed.
