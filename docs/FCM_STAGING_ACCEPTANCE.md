# Signals FCM staging delivery

Package `com.codephantom.app`, Firebase project `codephantom-technologies`.
This branch stacks on app draft #18; its backend counterpart stacks on #26.
Neither stack is merged or deployed. Scanner/baseline data and processes are untouched.

## Android configuration and build

The owner supplied staging Environment secret
`FIREBASE_GOOGLE_SERVICES_JSON_BASE64`. The staging build job explicitly uses
`environment: staging`, validates base64/JSON/project/sender/package, then writes
`android/app/google-services.json` with restrictive permissions. It never prints
contents; cleanup runs even on failure. Native Gradle resources initialize
Firebase; do not duplicate Android options in Dart definitions. The local file
is git-ignored. A service-account JSON is NOT an Android client config.

Run Actions **Build Android Staging APK** on `feature/signals-fcm` for an
installable debug-signed staging APK with `PUSH_ENABLED=true`. This is NOT an
owner release signature. Run **Android release** manually on the same branch
for an owner-signed staging APK/AAB. The staging Environment must also contain
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD` and variable `API_BASE_URL` (HTTPS, staging `/api/v1`).
Never substitute a debug keystore to satisfy release acceptance. The release
workflow verifies the APK signature and refuses the Android Debug signer.
Neither workflow deploys. Staging Firebase opt-in does not enable production push.

For local validation/build:
```
python scripts/firebase_android_config.py --validate-file android/app/google-services.json
python -m unittest discover -s scripts -p test_firebase_config.py
node --test scripts/test_web_push.cjs
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define=APP_ENV=staging --dart-define=PUSH_ENABLED=true --dart-define=API_BASE_URL=https://code-phantom-backend-staging.up.railway.app/api/v1
```

## Railway server configuration (owner action, no automatic deployment)

In the **staging backend service only**, configure existing provider variables:
`PUSH_PROVIDER=fcm`, `PUSH_FCM_PROJECT_ID=codephantom-technologies`,
`PUSH_FCM_CLIENT_EMAIL=<dedicated sender service-account email>`,
`PUSH_FCM_PRIVATE_KEY=<its PEM private key>` (real newlines or escaped `\n`).
Enable Firebase Cloud Messaging API (HTTP v1) in that project. Grant the sender
only the project permission required to send Cloud Messaging messages (Firebase
Cloud Messaging API Admin), not Owner/Editor. Generate/store credentials through
the owner console; never send a private key in chat, commit it, upload it as an
artifact, or put it in Flutter/Docker build args. Rotate/revoke compromised keys.
If a future authorized GitHub backend deployment needs these values, put them
in the protected backend staging Environment secrets and map only to server
runtime; ordinary CI tests use generated test keys and need no real credentials.

Preserve the existing staging database/auth/licence configuration. Confirm
`scanner.client_notifications`, market enabled/release cohort, active licence
and both view + notification entitlements for the test customer. Do not enable
flags or grant access automatically to make a test pass. Token endpoints use
authenticated sessions; tokens/outbox are private and denied to customer roles.
The worker rechecks session, account, licence/device policy and market grants
immediately before sending. FCM acceptance is not phone delivery.

Review backend #25 -> #26 -> companion Web registration migration in order.
Take and verify a staging DB backup, dry-run in a disposable database, confirm
`/health` says staging and `/ready` has the new schema marker, then obtain owner
authorization for migration/deploy. The new migration extends only the platform
constraint; existing tokens, signals and journals are preserved. Roll back code
with `PUSH_PROVIDER=none` and web opt-in off; retain the additive schema and
historical outbox. Do not drop tables or delete Web rows as a rollback shortcut.

## Web Push: installed iPhone PWA and desktop

Android configuration does not configure Web Push. Create a separate **Web app**
in the same Firebase project and generate its public Web Push VAPID key. In the
app staging Environment set public variables `PUSH_WEB_ENABLED=true`,
`PUSH_FIREBASE_WEB_APP_ID`, `PUSH_FIREBASE_WEB_API_KEY`,
`PUSH_FIREBASE_SENDER_ID`, `PUSH_WEB_VAPID_KEY`. The Web staging workflow generates
the worker and passes these public values to Flutter. A private VAPID key or
service-account key never belongs here. Web IDs must have `:web:` rather than
`:android:`. Public client API keys must allow Firebase Installations/FCM
registration; an Android-only key restriction cannot serve the web client.

For a separately authorized Railway PWA rollout, pass public Docker build args
`PUSH_ENABLED=true`, `PUSH_FIREBASE_PROJECT_ID=codephantom-technologies`,
`PUSH_FIREBASE_APP_ID=<web ID>`, `PUSH_FIREBASE_API_KEY=<web public key>`,
`PUSH_FIREBASE_SENDER_ID`, `PUSH_WEB_VAPID_KEY`; retain staging API/CORS origins.
HTTPS must serve `/firebase-messaging-sw.js` as JavaScript (not index.html),
with no-cache; the existing offline worker remains separate and never caches auth.
The CSP permits only the required Google SDK/registration hosts, not wildcard
origins. Browser support is checked before registration. Unsupported browsers
fail without registering a token. Permission is requested only from the alert
switch after login, not on page load. iPhone/iPad requires iOS/iPadOS 16.4+,
Add to Home Screen, then open the installed PWA and explicitly enable alerts.
Native iOS APNs setup is a separate product/build requirement, not PWA setup.

## Physical acceptance: record evidence, never fabricate it

For each test record UTC, source commit/APK SHA and signer, OS/browser/version,
backend target, redacted registration/delivery/event IDs and screenshot/video.
Do not record raw FCM tokens, JWTs or account secrets. Use genuine authorized
staging events or clearly labelled test fixtures, never fake trade outcomes.

1. Android 13+ with Google Play services: login as entitled customer; deny alerts
   first (no registration), then enable; verify permission and channel settings.
2. New signal in foreground: one neutral in-app banner; View opens the referenced
   signal through fresh authorized API reads. No strategy identity/private notes.
3. Repeat with app backgrounded, phone locked, and app normally terminated:
   one OS notification, correct icon/channel; tap opens the same signal. Android
   force-stop suppresses FCM until reopening: record that limitation explicitly.
4. Verify TP/SL/cancellation events only when evidence exists; ambiguous outcomes
   produce no false TP/SL. Retry the same publisher event: one outbox event and
   delivery. Event tags and persisted foreground/tap IDs suppress repeats;
   send-then-crash ambiguity is at-least-once, not an exactly-once guarantee.
5. Token refresh/reinstall, app restart and session restore: stable installation
   on refresh; rotation invalidates older queued delivery revisions. Secure
   logout unregisters before auth clearing and deletes the FCM token even offline;
   late refresh callbacks do not restore the logged-out registration.
6. Revoke market/view/notification grant, expire licence, suspend user or revoke
   session before a queued send: no delivery. Tap an older notification afterward:
   unavailable/denied state, never cached private signal details. Test another
   customer and another market; no cross-user/cross-market broadcast.
7. Installed iPhone Home Screen PWA and supported desktop browser: repeat
   foreground/background/locked-screen tap, permission denial/recovery, logout,
   entitlement revocation and duplicate-event checks. Desktop closed-browser
   delivery depends on OS/browser background settings; record actual behavior.

Unit tests/build artifacts cannot establish physical acceptance. Remaining
owner actions are server credentials/IAM, protected release signing material,
Web public configuration, authorized staging migration/deploy and real devices.

Sources: [Firebase Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages),
[HTTP v1 authorization](https://firebase.google.com/docs/cloud-messaging/send/v1-api),
[Web setup](https://firebase.google.com/docs/cloud-messaging/web/get-started),
[Apple Home Screen Web Push](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/).
