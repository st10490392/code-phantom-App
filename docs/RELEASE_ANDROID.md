# Android release process

Automation: `.github/workflows/flutter-ci.yml` (every PR/push: analyze,
test, debug APK) and `.github/workflows/android-release.yml` (signed AAB +
APK per environment). No app source (`lib/**`) or dependency changes were
needed for either.

## One-time setup (owner actions)

### 1. Create the Android release/upload key (keep it forever)

```bash
keytool -genkeypair -v -keystore codephantom-upload.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias codephantom-upload
```

Store the `.jks` file and both passwords in a password manager **and** an
offline backup. For APKs distributed directly from the CodePhantom website,
this key is the Android signing identity that lets future releases update the
installed app. Losing it can prevent compatible updates; leaking it could let
someone sign an app as CodePhantom. If Google Play is added later, enable
**Play App Signing** and use this keystore as the upload key where appropriate.
Never commit the keystore or `android/key.properties` (both are git-ignored).

### 2. GitHub Environments

Repository → Settings → Environments → create `staging` and `production`:

| Kind | Name | Value |
|---|---|---|
| secret | `ANDROID_KEYSTORE_BASE64` | `base64 -w0 codephantom-upload.jks` |
| secret | `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| secret | `ANDROID_KEY_ALIAS` | `codephantom-upload` |
| secret | `ANDROID_KEY_PASSWORD` | key password |
| variable | `API_BASE_URL` | `https://<staging-api-host>/api/v1` or `https://<production-api-host>/api/v1` |

Protect `production` with **required reviewers** so a production build
needs an explicit approval. (The same upload key may be used for both; the
staging build is distinguished by its API URL. If staging builds must be
installable side-by-side with production, add an `applicationIdSuffix`
flavour later - a Flutter-team change.)

### 3. Permanent application ID

The Android application ID is locked to `com.codephantom.app`. Treat it as
permanent from the first public APK onward: changing it later makes Android
see a different application rather than an update. The existing Android/Kotlin
namespace remains separate and does not need to be migrated just to use this
application ID.

## Building a release

- **Staging build:** Actions → *Android release* → Run workflow →
  environment `staging` (optional version name). Artifacts: `app-release.aab`,
  `app-release.apk`, `SHA256SUMS.txt`; debug symbols as a separate private
  artifact.
- **Production build:** push a tag `vX.Y.Z` (or run manually with
  `production`). The build waits for the environment approval, then also
  attaches the AAB/APK to a **draft** GitHub Release.

Every build: `flutter test` → signed `--release --obfuscate` AAB + APK with
`--dart-define=APP_ENV=production --dart-define=API_BASE_URL=<env var>` →
the job **fails if the APK is unsigned or debug-signed** → signing files are
deleted from the runner.

Versioning: `versionName` = tag (without `v`) or the manual input, else
`pubspec.yaml`; `versionCode` = the workflow run number (monotonic).

## Publishing

1. Build and smoke-test `staging` against the staging backend first.
2. For the initial website-distributed release, build `production` from a
   version tag. The workflow creates a draft GitHub Release containing the
   signed APK, AAB and `SHA256SUMS.txt`. Publish the release only after the APK
   is tested on a real Android device, then expose that exact APK URL/version/
   SHA-256 on the website `/download` page.
3. If Google Play is added later, upload the AAB through internal/closed testing
   before production rollout and enable Play App Signing.
4. Rollback by shipping a known-good commit with a higher `versionCode`;
   server-side features can also be disabled with backend feature flags without
   requiring an app release.

## Play Console checklist (owner)

Developer account, app listing, privacy policy URL (website), Data safety
form (the app stores auth tokens and a random installation id in secure
storage; no hardware identifiers), content rating, target audience, and -
for anything trading-related - accurate, non-promissory store copy with no
performance claims.
