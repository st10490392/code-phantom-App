# ENKIDU app staging reconciliation R1

## Sources and base

Railway staging PWA deployment `a2dbf998-ca93-4e05-87f5-fa81bdbd5a09` runs
`fd102d8d7e48be3d9a3aad2e88d131e6ce7397c5` from
`release/v1.0.0-production`. This branch starts at that exact commit and targets
the same release branch for review only. Pushing this isolated branch does not
trigger the release branch's signed build or Railway deployment.

Original App PR #20 remains at `9f62aeaa60e25b238c8e7825ddf9934ddade275f`,
stacked on FCM/deep-link PR #19. Its history was 16 ahead/3 behind staging.
The existing feature stack is integrated locally, preserving the deployed side
of licensing and paused EA behavior. Neither original PR is changed.

## Explicit comparison and resolutions

| Deployed feature missing/divergent on bridge head | Reconciled behavior |
| --- | --- |
| One-time Scanner activation and Scanner-first registration | Preserved, including dashboard activation gate and real API services |
| Account-specific device store and active-account tracking | Preserved; no global device ID fallback |
| Authenticated `X-CP-Device-Id` and token refresh | Preserved for existing and V5 API calls |
| Replacement-device key redemption and unbound-installation UI | Preserved, with explicit bound/unbound dashboard tests |
| Owner key issuance, lifecycle management and `/licences` authorization | Preserved in routing, navigation and services |
| Signed release build/signing safeguards | Existing deployed release workflow retained; not executed |
| Read-only EA monitor and paused real command methods | Preserved; feature ancestry's command-submission changes deferred |
| FCM/Web Push and signal deep links | Existing implementations retained; registration now resolves the current account's device binding |
| Live signal outcome display | Existing outcomes retained plus imported cancellation/privacy projection handling |
| V5 owner-only SHADOW view | Original versioned read contract, provenance/nonexecution labels, owner guards and default-off build flag retained |

The old FCM controller read `account_device_id`, while deployed licensing uses
`licensing_server_device_id:<user>`. Registration now obtains the binding from
the existing `DeviceIdentityStore` for the current user, checks its generation
after asynchronous reads, and omits a missing binding rather than substituting
another account's ID. Backend licensing rules remain authoritative.

The source stack's GILGAMESH panel is retained as existing source, but it does not
replace the deployed EA monitor. No command-submission feature or broker control
is introduced. The original feature work remains available in its original PR.

## Verification

Flutter/Dart are unavailable locally and no SDK is installed by this checkpoint.
PR CI installs Flutter 3.47.5, checks changed Dart formatting, runs analysis and
the complete Flutter suite, then compiles Android debug, web and unsigned iOS.
Firebase configuration and Web Push fixture tests also run. PR CI does not sign,
publish or upload an APK; artifact quota therefore cannot conceal test failures.

Regression coverage includes owner licence-route authorization, Scanner-first
registration, activation gating, persistent account-specific device identities,
replacement-device gating, session refresh, notification logout/retry/deep links,
per-account push registration, and V5 owner/customer/default-off behavior. The
existing real EA-control tests continue to require zero command requests.

```sh
flutter pub get
flutter analyze
flutter test
python3 -m unittest discover -s scripts -p test_firebase_config.py
node --test scripts/test_web_push.cjs
flutter build apk --debug
flutter build web --release --no-web-resources-cdn
flutter build ios --release --no-codesign  # macOS CI only
```

CI results must be taken from this reconciliation PR's exact head; original
PR #20's success is insufficient. No new signed APK or physical phone acceptance
is claimed. No V5 push sender is implemented.

## Deployment dependencies and rollback

Backend reconciliation must preserve its exact deployed licensing/outcome source
and pass CI. Its real DB identity, CLI history and October 6 archive SQL remain
unverified; see the backend compatibility report. No staging schema rehearsal
or migration is authorized or claimed here.

Future gates: independently verified disposable staging schema rehearsal;
verified Gate authority and owner observation custody; reviewed rollout plan;
artifact capacity; separate approval for staging migrations/deployment, producer
provisioning, owner flags and private signed APK build/installation. Installing
an old signed APK does not demonstrate V5. Public website APK distribution is a
separate decision and is not used for the owner-only staging build.

Rollback: turn off V5 display/ingest, retain the previous signed APK and deployed
PWA source `fd102d8...`, and restore those builds only after owner approval. Keep
the same application ID/signing key and ensure the future update version code
is greater than the installed build. Preserve account-specific secure-storage
keys, receipts and backend audit records; do not clear app data or licensing
bindings as a release workaround. No signed distribution occurs here.
