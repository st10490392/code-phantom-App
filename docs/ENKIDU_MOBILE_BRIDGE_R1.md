# Owner V5 SHADOW view R1

The existing Android/PWA app gains an owner-only `/enkidu-shadow` route and navigation item. It uses the existing authentication and API client, reads the private backend V5 endpoint, and displays UTC cutoff, observation and expiry, provenance hashes, theoretical levels and a clear nonexecution label. Customer deep links redirect to Dashboard. No customer signal list, performance summary or notification route is reused.

The local build flag `ENKIDU_SHADOW_VIEW_ENABLED` defaults false; the backend also has an independent disabled display flag and OWNER check. The previously signed staging APK predates this view and must be rebuilt and signed from this branch only after a separate staging approval. The existing manual staging signed-APK and PWA artifact workflows now have an `enkidu_shadow_view` input, default false, that passes the build flag when approved. Neither workflow was run here. No V5 FCM sender or live phone acceptance is claimed.

Flutter/Dart are unavailable locally. The pull-request `Flutter CI` workflow installs Flutter 3.47.5 and checks formatting of the changed Dart files, analyzes and tests the app, and builds Android debug and web artifacts. CI outcomes must be checked on this PR before claiming Flutter verification. A signed staging APK and physical Android/PWA acceptance remain separate gates.
