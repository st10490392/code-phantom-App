# Private Android release candidate R1

Source branch: `reconcile/enkidu-staging-r1`, draft PR #21. This checkpoint
authorizes a private signed APK build only. It does not authorize a merge,
Railway deployment, migration, website update, installation or ENKIDU activation.

Candidate: `com.codephantom.app`, version `1.0.1-rc1`, code **14** (public APK
code 3; previous staging code 13). Signing certificate SHA-256 must equal
`67b51a8fa5577620451f83c767cc3c41b72e38464ee6f47a1707e5815622b7ae`.
No new key is generated or retrieved. Existing staging Environment secrets are
consumed only by the existing release workflow's temporary runner-local setup.

## Build and verification

Dispatch `.github/workflows/android-release.yml` at this branch with
`release_candidate_r1=true`, `enkidu_shadow_view=false`. The staging Environment's
`API_BASE_URL` must exactly equal
`https://code-phantom-backend-staging.up.railway.app/api/v1`. A mismatch blocks
before signing. No automatic RC build or public release trigger is added.

The RC path builds one APK (no AAB), after analysis and all Flutter tests. It
embeds a nonsecret source/config identity and verifies the actual APK using
Android `apksigner` and `aapt`: certificate, package, code/name, SDK 24/36,
ABIs, non-debuggable state, explicit permission allowlist, native Firebase
resources, compiled API URL, and embedded source/config. The same builder sets
the compile arguments and embedded identity. ENKIDU view and Scanner review
actions are explicitly false; existing EA controls remain paused. Notification
transport is compiled, while registration and permission remain user opt-in.

The private artifact includes the APK, verification JSON, checksum, resolved
dependency lockfile and obfuscation symbols. It expires after 30 days. No
signing material is included. If upload quota fails, inspect a supported private
retrieval alternative; do not delete evidence, publish, or log APK bytes.

Tests: `python -B -m unittest discover -s scripts -p test_android_rc_r1.py`.
Fixture tests enforce wrong destination, enabled V5, wrong signer, downgraded
version, unsupported permissions/SDK/ABIs and tampered build identity rejection.
Actual artifact results are recorded in the run's `verification.json`, not
inferred from fixtures. PR CI includes these checks plus existing Flutter,
auth/licensing/device, notification lifecycle, Android/web/iOS compilation tests.

## Owner installation and rollback precautions

Before installing, verify the artifact checksum, package, certificate and that
the currently installed version code is below 14. If a newer unknown build is
installed, stop and request a higher-code candidate. Do not uninstall or clear
app data: preserve encrypted session storage, installation identity and
account-specific licensing bindings. Record only nonsecret acceptance results.

An approved in-place test must check session restoration (or normal re-login if
expired), licence access, device binding, notification permission/opt-in,
registration/rotation/logout and authenticated deep links. No device acceptance
is claimed by CI. Push backend rollout and the independently verified staging
database remain separate blockers; this APK does not activate ENKIDU.

Android does not provide an ordinary downgrade path preserving this state.
Rollback requires a build of the previous source signed with the same key and
a version code above the installed candidate. Never delete bindings or app data
as a workaround. No backend/database change is part of this milestone.
