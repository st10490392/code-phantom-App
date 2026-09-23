# Backend platform integration - what the app will need

The backend now provides the account/licence/device platform. **Nothing
here is implemented in the app yet** and nothing in this sprint touched
`lib/**`; this is the hand-off for the Flutter team.

Authoritative contract: code-phantom-backend
`docs/contracts/mobile-app-platform.v1.md` (+ `openapi/platform.yaml`).
Summary:

| Area | Backend | App work (future) |
|---|---|---|
| Login | `POST /auth/login` now accepts `identifier` (email **or** username); `email` still works | optional: label "Email or username", send `identifier` |
| Signup | `POST /auth/signup` (flag `accounts.signup`, off at launch) | signup screen with username availability (`GET /auth/username-availability`) |
| Email verification / recovery | Supabase emails redirect to `codephantom://auth-callback` | add the Android intent filter + link handling |
| Activation | `POST /me/activation {activation_key, device}` - one-time key, binds first device | activation screen; generate + persist a random `installation_id` (UUID) in secure storage; persist returned `device.id` |
| Every request | send `X-CP-Device-Id: <device.id>` | add to `ApiClient` headers once activation ships |
| Access | `GET /me/access` - entitlements, visible Scanner markets, features, `fresh_until` | drive module/market visibility from it (not from plan names); offline cache only until `fresh_until` |
| Local PIN | client-only (never sent) | 4-8 digits, KDF + Keystore, local rate limit, reset via full login |
| Devices & sessions | `GET /me/devices`, `DELETE /me/devices/{id}`, `GET /me/sessions`, `POST /auth/logout-all` | Security settings screen |
| Replacement phone | `POST /me/devices/rebind {binding_key, device}` | "I have a device key" flow |
| Support | `/support/tickets` | Support screen incl. "Lost device" |
| Errors | `DEVICE_REVOKED`, `SESSION_REVOKED`, `LICENCE_NOT_ACTIVE`, `EMAIL_NOT_VERIFIED`, … with `request_id` | map to screens; show `request_id` in error details for support |
| Logout | `/auth/logout` now signs out **this** session only (was: every device) | no change needed |

Environments: the app's `AppEnvironment` has `mock | development |
production`. Staging builds use `APP_ENV=production` with a staging
`API_BASE_URL` (see `docs/RELEASE_ANDROID.md`). Adding an explicit
`staging` value later is optional.

Backend enforcement of device binding (`devices.enforce_binding`) stays
**off** until an app release that sends `X-CP-Device-Id` is rolled out, so
the current app keeps working unchanged.
