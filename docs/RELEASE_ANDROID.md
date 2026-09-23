# Android release process

Automation: `.github/workflows/flutter-ci.yml` (every PR/push: analyze,
test, debug APK) and `.github/workflows/android-release.yml` (signed AAB +
APK per environment). No app source (`lib/**`) or dependency changes were
needed for either.

## One-time setup (owner actions)

### 1. Create the upload key (keep it forever)

```bash
keytool -genkeypair -v -keystore codephantom-upload.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias codephantom-upload
```

Store the `.jks` file and both passwords in a password manager **and** an
offline backup. Losing the upload key means asking Google Play support for
a reset; leaking it lets someone publish updates as you. Use **Play App
Signing** (Google holds the app-signing key; this is only the upload key).
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

### 3. Application ID - decide before the first Play upload

`android/app/build.gradle.kts` still has the generated
`applicationId = "dev.codephantom.code_phantom_app"`. It can **never change**
after the first Play Store upload. Decide the permanent id (e.g.
`com.codephantom.app` on a domain you control) and have the Flutter team
change it before the first release.

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

1. Upload the staging AAB to a Play **internal testing** track; smoke-test
   against the staging backend (docs in code-phantom-backend
   `docs/RUNBOOK.md` §3).
2. Build production from the same commit (tag), upload to internal testing
   → closed testing → production with a staged rollout (e.g. 10 % → 50 % →
   100 %).
3. Rollback: halt the staged rollout in Play Console, or ship a new build
   with a higher `versionCode` from the previous good commit. Server-side
   features can be switched off with backend feature flags without an app
   release.

## Play Console checklist (owner)

Developer account, app listing, privacy policy URL (website), Data safety
form (the app stores auth tokens and a random installation id in secure
storage; no hardware identifiers), content rating, target audience, and -
for anything trading-related - accurate, non-promissory store copy with no
performance claims.
