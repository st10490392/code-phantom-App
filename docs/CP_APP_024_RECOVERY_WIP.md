# CP-APP-024 recovery work in progress

This branch introduces a separate RC17 one-shot storage slot and requires a read-only staging backend readiness response before the Send action can be enabled. RC16 storage remains untouched; no existing UUID is replayed. The client fails closed when readiness is unavailable.

**NOT RELEASE READY.** Backend route `GET /api/v1/notifications/push/staging-test/readiness` does not yet exist and must be implemented in a separate staging-only backend draft branch with OWNER/device authorization, `ready`, `environment: staging`, and `eligible_registration_count: 1` fields. Existing app tests still assume immediate readiness and need to be updated with preflight fixture responses and new assertions. No APK should be built or installed until both changes pass CI. Preflight must not claim Firebase delivery. Never auto-send, reset on uncertain outcomes, or relax staging-only controls.

Current branch is deliberately draft/WIP, no deployment, no test push, no production modifications.
