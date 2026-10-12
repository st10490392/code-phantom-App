# CP-APP-022: private staging phone-alert candidate

Base: draft PR #21 `beb2147cd27459d167a7ce5114b9e6300d267a4a`.
Branch: `fix/cp-app-022-owner-phone-alerts`. PR #21 is preserved.
RC14 is `com.codephantom.app`, 1.0.1-rc1/code14, SHA-256
`8ca598b7184ca97989da2001e24fc53b0ef793fa971273560f49c6e573164ee9`.

## Trace and fix

Settings -> enable -> notification permission -> Firebase token -> random push
installation UUID -> current account's stored licence device ID -> authenticated
POST /notifications/push/register. OWNER bypasses CLIENT licence activation and
usually has no stored licence device ID. The app already omits that field;
the reconciliation backend's binding enforcement has no OWNER exception.
Its DEVICE_REQUIRED response is caught and replaced by the generic error.
This is a source-confirmed contract defect; no authenticated phone response
body or real token is collected in this checkpoint.

The necessary isolated backend fix uses server-held OWNER authority and a
verified active session to own the push installation without manufacturing a
CLIENT licence. CLIENT binding, licence and replacement restrictions stay in
force. Any supplied device ID remains server-validated. No client-side role
claim or backend authorization bypass is added.

The app validates stored device UUIDs before HTTP, reports sanitized
authorization/session failures, and distinguishes retained opt-in from confirmed
registration. A malformed success response cannot show registered. An existing
403 remains denied until the backend permits the operation; resume retries only
under the current session/generation. Tokens and raw error bodies are not logged.

Six added Flutter regressions cover unlicensed OWNER request shape, licensed
CLIENT binding, missing authentication, invalid identity, denial/recovery and
malformed registration success. Existing account-switch/logout, token refresh,
permission, offline unregister, auth and licence tests remain applicable.

## Private signed build

Candidate: 1.0.1-rc2/code15, application ID com.codephantom.app. Original
certificate SHA-256 is required:
`67b51a8fa5577620451f83c767cc3c41b72e38464ee6f47a1707e5815622b7ae`.
Use the existing Android release workflow with release_candidate_r1=true and
enkidu_shadow_view=false on this exact isolated branch. Manual builds select
the staging GitHub Environment. API URL must equal
https://code-phantom-backend-staging.up.railway.app/api/v1 .
The release script verifies actual APK package/code/signature/permissions,
Firebase resources, compiled URL and embedded source/environment identity.
ENKIDU view, Scanner review and execution remain disabled. No new permissions
or changes to secure storage, authentication or licensing activation are added.

CI runs formatting, analysis, all Flutter tests, Firebase/RC/Web Push checks,
Android debug, web and unsigned iOS builds. Signed build repeats analysis/tests
and creates one release APK. Signing secrets remain within the authorized
runner. Artifact storage fallback remains an unpublished draft in the existing
private repository; no public release, website update or deletion is allowed.
Final APK hash, source, build run and private retrieval link are recorded after
actual build and independent retrieval, never inferred from configuration.

## Owner acceptance and rollback

1. Verify candidate checksum and original signer; install over RC14 without
   uninstalling or clearing data. Confirm code15 and staging environment.
2. Confirm login/session restore, licence screen, signals and existing controls.
3. With the separately reviewed compatible staging backend deployed, opt in to
   Signal alerts. Registration must succeed without OWNER licence activation;
   the toggle alone is not proof. Disable and re-enable, then background/resume.
4. Verify CLIENT still requires its own activated/bound device. Do not reuse
   another account's identity or expose notification tokens in screenshots.
5. Physical receipt requires a separate safe owner-only test; registration and
   server acceptance do not prove Android delivery.

Rollback preserving data requires prior app source rebuilt with the SAME
certificate/package and versionCode greater than the installed candidate.
Do not install code14 as a downgrade or clear app data as a workaround.
Backend rollback preserves registrations and schema; no destructive down SQL.

No merge, backend deployment, hosted DB mutation, Azure/VM action, public
publication, ENKIDU activation, automatic fanout or trading is included.
