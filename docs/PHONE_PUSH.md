# Phone alerts

Backend companion: [draft PR #24](https://github.com/st10490392/code-phantom-backend/pull/24), branch `feat/phone-push-notifications`.

The phone app uses Firebase Cloud Messaging for Android and iOS notifications. Web, desktop and mock builds do not initialize Firebase. Notification permission is requested only when the signed-in customer enables **Settings → Phone alerts**. The app stores the installation UUID and consent in secure storage, registers the token using its normal authenticated API client, rotates refreshed tokens, and unregisters before logout. Session loss deletes the local Firebase token. Resume retries transient registration failures, APNs startup delays, and an offline opt-out's server cleanup. Binding enforcement remains server-authoritative: if enabled, registration needs the account's verified device ID, stored as `account_device_id`; no device/binding bypass is added.

Background/terminated messages use native notification payloads. Foreground messages show a simple banner and refresh the notification/signal lists; repeated event IDs are ignored. Taps open the notification centre through the normal authenticated router. No message-provided route is followed and no private metadata is rendered. Scanner cards/detail additionally hide strategy profiles, publisher IDs and notes from customers, including when an older backend still returns them. Staff retain their review diagnostics.

## Environment-specific build configuration

No Firebase project, service account, APNs credential or production configuration is created by this PR. `PUSH_ENABLED` defaults false. For a later authorized phone build, use public Firebase client settings matching the selected backend sender project:

```text
--dart-define=PUSH_ENABLED=true
--dart-define=PUSH_FIREBASE_PROJECT_ID=<project ID>
--dart-define=PUSH_FIREBASE_APP_ID=<platform-specific Firebase app ID>
--dart-define=PUSH_FIREBASE_API_KEY=<public client API key>
--dart-define=PUSH_FIREBASE_SENDER_ID=<messaging sender ID>
```

Use a non-mock APP_ENV and the correct API_BASE_URL. Firebase app IDs differ between Android and iOS. Do not put the backend's FCM service-account email/private key or Supabase service-role key in these values.

- Android application ID stays `com.codephantom.app`. Download that app's `google-services.json` into `android/app/`. The Google Services Gradle plugin is applied only when the file exists, preserving unconfigured mock/CI builds. Native resources are required for delivery after the app process exits. Android 13+ requests runtime notification permission; the `codephantom_signals` high-importance channel and white notification icon are configured.
- iOS bundle ID stays `dev.codephantom.codePhantomApp`. Put that app's `GoogleService-Info.plist` in `ios/Runner/`; an optional build phase copies it into the app bundle. Enable Push Notifications for the existing app identifier/signing profile and associate an APNs key/certificate with Firebase. The project sets `aps-environment` to development for Debug and production for Release/Profile, enables the remote-notification background mode, and initializes the notification-centre delegate before the UIScene lifecycle registers plugins. Existing app identities/signing choices are preserved.

The two native client config files are ignored. They must match the Dart public configuration. Firebase token auto-init starts disabled and is enabled after signed-in opt-in; disabling alerts/logout disables it before token deletion. There is no data-only background handler or trading operation.

## Verification

Run `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`, and `flutter build web --release --no-web-resources-cdn`. Existing Flutter CI runs these checks for draft PRs. Dependencies are pinned to published Firebase Core 4.15.0 and Messaging 16.7.0; minimum Dart is 3.6 (the existing CI Flutter version is newer). The repository's existing policy ignores pubspec.lock.

New fake-transport tests cover explicit consent, denial, authenticated registration, installation stability, token rotation, late callbacks, pending token lookup on logout, foreground/tap deduplication, cold-start taps, transient failure/resume, missing APNs token, offline opt-out cleanup, unsupported builds, and payload privacy. Widget regression tests prove customer detail hides strategy/hash metadata while staff still see diagnostics.

Before rollout, verify on configured physical Android and iOS phones: foreground, background and terminated delivery; accept/deny permissions; new signals, TP and SL; taps after sign-in; logout/account switch; token refresh; grant/cohort/device revocation and licence expiry. Inspect the displayed text and payload for strategy/version/hash leakage. Firebase delivery is durable at least once; a provider-accepted alert can still arrive after opt-out/logout, and native tags/collapse IDs plus in-app deduplication reduce duplicate presentation. No live-device delivery was tested in the unconfigured workspace.
