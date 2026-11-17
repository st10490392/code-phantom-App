# CodePhantom App — Project Roadmap

This roadmap is intentionally conservative. Verify each item against the current active branch before changing its status. Reports from earlier chats or stale docs are not proof of current implementation.

## Immediate priorities
1. Reconcile current active app branch with docs/CURRENT_STATE.md and open PRs. The default-branch README and some older docs describe an earlier mock-first stage; do not treat them as current without branch verification.
2. Verify the owner-only Integrations screen, permission gates, API contracts and tests on the active development branch. Prior Cline report: implementation and service tests were reported complete; a full UI interaction test and GitHub push/PR were not confirmed.
3. Verify licensing screens and API service against the backend's current licence/entitlement contract. Ensure UI never treats client-side expiry/status as authoritative.
4. Verify app/backend contract compatibility for authentication, signals, EA monitoring, integrations and notifications.
5. Confirm Android build prerequisites. Earlier local environment report: JDK 8 was installed, while the Android Gradle toolchain required JDK 17+. Recheck before attempting release builds.

## Product direction
- Keep app customer/owner workflows clear, reliable and responsive.
- Keep PH-SIGNALS and PH-EA visibly and technically separate.
- Replace mocks only when the matching backend contract and service are verified.
- Keep remote EA controls, signal publishing, payments and other risky operations disabled until independently tested and explicitly approved.
- Do not add trading strategy or execution logic to the app.

## Release gates
- Backend authorization and entitlement tests pass.
- No mock data is presented as live.
- Auth/session lifecycle and secure storage are verified.
- API error, offline, loading and empty states are handled.
- Flutter analyze, relevant tests and target builds are run and their exact results recorded.
- Real-device verification is distinguished from emulator/browser testing.
- No production rollout without owner approval.

## Status labels
Use: VERIFIED IN SOURCE, TEST-VERIFIED, STAGING-VERIFIED, PRODUCTION-VERIFIED, REPORTED BUT NOT INDEPENDENTLY VERIFIED, PLANNED, BLOCKED.
