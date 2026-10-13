# CP-APP-023: Android owner staging test action

Base RC15: 8ca49362631f185d0cc5741c6e7305805e030bbc. Isolated branch:
fix/cp-app-023-staging-push-action. Candidate 1.0.1-rc3+16 preserves
com.codephantom.app and signer SHA256
67b51a8fa5577620451f83c767cc3c41b72e38464ee6f47a1707e5815622b7ae.

Read-only Railway inspection confirmed staging CP-BE-033 source
21b04f41589e86f86bba9b6d9b09637a183c6d4e at deployment
9efc5514-a460-48cc-9086-55f592180ee1. No deployment or variables were changed.

## Behavior

An ACTIVE OWNER on Android in APP_ENV=staging sees Send Test Notification
beside the existing phone-alert settings. CLIENT, production, mock/development,
iOS and PWA do not expose it. Existing authentication/licensing/binding rules
are unchanged; backend CP-BE-033 remains the authority.

Canceling the confirmation sends nothing. Confirming generates a fresh UUIDv4,
persists it under a per-owner RC16 secure-storage key, and submits precisely:
POST /notifications/push/staging-test with invocation_id and
confirmation=SEND_ONE_STAGING_TEST through the existing authenticated ApiClient.
The new postOnce method never retries a submitted request after401; existing
API methods retain their current refresh/retry semantics. A pre-send token
refresh may still establish the existing session, without repeating the operation.
Active account identity is checked before network transmission.

The button latches disabled synchronously and stays disabled after every result,
including lost responses and server rejection. The persisted latch survives
screen/controller recreation, restart and normal logout. There is no reset UI.
One invocation per owner for this release is intentional. Never clear application
data to bypass it. Restoring older device storage/uninstalling can remove the local
latch; server-side durable invocation history remains the replay authority.

Only fixed sanitized messages are shown. ACCEPTED explicitly does not claim
delivery. A matching STAGING_PUSH_TEST receipt has no signal ID; foreground
receipt shows fixed diagnostic text for staging OWNER Android only. A diagnostic
tap returns to settings, never a trade screen. Raw provider bodies/routes are ignored.

## Verification and gates

CI installs the existing pinned Flutter SDK; no SDK installed on the Windows host.
Run Flutter formatting/analyzer/all tests, Python Firebase/RC checks, Android/web
and unsigned iOS builds. Tests cover environment/role visibility, confirmation,
one UUID invocation, duplicate taps, persisted uncertainty,401/no replay,403,
missing session/account switches and diagnostic payload isolation. Final exact
CI counts and artifact hashes are in the draft PR handover.

Existing manual signing workflow builds private staging RC16 and verifies package,
version, original signer, permissions and embedded staging/source identity.
If Actions storage is full, its existing private unpublished-draft fallback is
permitted; no public Release/tag/website update. ENKIDU view, Scanner review,
execution and customer publication remain disabled in this candidate.

Install over RC15 without uninstalling or clearing storage. Check login, licensing,
signals and registration first. Before confirmation ensure exactly one eligible
Android registration and use its existing OWNER session. The server staging-test
switch and FCM readiness must already be separately approved/configured; this app
work neither enables them nor sends a test itself. Confirm once when ready for
physical phone acceptance. Do not equate API acceptance with device receipt.

Rollback needs the original signer/package and a higher Android versionCode;
do not force a downgrade or erase local data. Backend or release distribution,
production changes, general fanout and ENKIDU activation are outside this task.
