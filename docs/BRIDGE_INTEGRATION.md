# Live Trading Bridge Integration (`api_server.py`)

This app talks to **two different services**, and the two are deliberately kept
apart. Nothing here is a contract the app invents: every path and body below is
read from the implementation that serves it.

## 1. The two backends

| | Primary API | Live trading bridge |
|---|---|---|
| Code | `code-phantom-backend` (`src/`) | `c:\CodePhantom`'s `api_server.py` |
| Owns | users, sessions, roles, permissions, entitlements, licence records, devices, push registrations, the signal *record* | the operator's live daemon state: MT5 status, open positions, analytics, pause/resume, the live event stream |
| Auth | Supabase Auth JWT (`Authorization: Bearer`) | HS256 JWT `scope=control` for control writes; a `SIGNALS` licence key for the stream |
| Response shape | `{ "data": … }`, errors `{ "error": { code, message } }` | bare JSON objects, errors `{ "detail": … }` |
| Base URL | `API_BASE_URL` (`lib/core/config/api_config.dart`) | `BRIDGE_BASE_URL` (same file) |

They are **not interchangeable**. The bridge has no accounts, no roles and no
JWT session; the API has no MT5 state and no WebSocket at all. The bridge is a
live trading bridge on the operator's host, not a legacy copy of the API.

## 2. Client wiring

- `lib/core/network/api_client.dart` — primary API. `{ data: }` envelope, bearer
  session, refresh-on-401, and `X-CP-Device-Id` **only after a real activation**.
- `lib/core/network/bridge_client.dart` — bridge. Bare JSON, `detail` errors, and
  no session: reads are unauthenticated, and the one write (`POST /control/toggle`)
  requires the bridge's own control token.
- `lib/features/live_feed/` — `GET /api/v1/stream` as a WebSocket: `key` (the
  device's `SIGNALS` licence key) and `hardware_id` as query parameters, per
  `api_server.py`'s `stream()` handler.
- `lib/features/trading_status/` — `/status`, `/positions`, `/analytics`,
  `/license/status`.
- `lib/features/licences/data/bridge_licence_service.dart` —
  `POST /api/v1/license/activate` (`SIGNALS` only).
- `lib/core/device/device_identity.dart` — the app-generated device UUID
  (primary API) and the bridge hardware id, both in `flutter_secure_storage`.

## 3. Build configuration (no secrets in the repo)

```bash
flutter build apk --release \
  --dart-define=APP_ENV=production \
  --dart-define=API_BASE_URL=https://api.codephantom.example/api/v1 \
  --dart-define=BRIDGE_BASE_URL=https://bridge.tailnet.example/api/v1
```

`BRIDGE_BASE_URL` has **no default**. A build without it reports
`LiveFeedStatus.unconfigured` and shows "no bridge configured" instead of
pretending to be connected. An `https://` origin becomes `wss://` for the stream,
so TLS can never be downgraded by accident. During development the bridge binds
to a tailnet address and is reachable only from authorized tailnet devices
(`config.API_HOST` is loopback or a Tailscale IP by design).

Never define a licence key, JWT, MT5 credential or backend secret as a
`--dart-define` flag: those are runtime credentials the app obtains from the
server, or operator-side secrets that belong on the trading host.

## 4. What the app deliberately does *not* do

- **No EA licence activation.** An `EA` key authorizes the daemon's dispatch
  gate, not a phone, and activation is one-time and hardware-bound; activating
  one from a phone would burn a key that can never authorize this client. The
  bridge's cross-service check stays the authority.
- **No fabricated positions or prices.** `GET /api/v1/positions` reports
  `floating_r` only when MT5 answers a tick; `null` renders as "no live price",
  never as a client-side guess. Malformed rows are dropped.
- **No trading-control credential on a phone.** `POST /api/v1/control/toggle`
  needs a `scope=control` HS256 JWT that the bridge never issues to a client.
  `BridgeTradingControlService` therefore refuses before any network call. The
  dashboard's pause/resume goes through the primary API's EA command contract
  (`POST /ea/accounts/:id/commands`, gated by `ea.control` plus the
  `ea.remote_commands` feature flag), behind
  `--dart-define=TRADING_CONTROLS_ENABLED=true`. Authorization is the server's
  decision; the flag only decides whether the UI offers the action.
- **No bridge push registration.** `POST /api/v1/push/register` registers a
  device against a licence key on the daemon. The primary API owns push
  registrations (`private.push_registrations`, entitlement-gated), so registering
  with both would double-deliver every alert. See `docs/PHONE_PUSH.md`.
- **No credential in a log or an error string.** The stream's licence key is a
  query parameter and is never logged; a refused key surfaces as
  "the trading bridge refused this device's SIGNALS key", not the key itself.

## 5. Reconnection rules

`BridgeLiveFeedService` retries with exponential backoff capped at
`backoffCap`, sends a keepalive frame every 20 s (the handler only reads
`receive_text()` to keep the socket warm), suppresses duplicate frames by content
key, and gives up after `maxConsecutiveFailures` **consecutive** failures. The
counter resets on `hello` — an authenticated subscription — not on a bare
handshake, so a bridge that accepts the socket and immediately drops it cannot
produce an infinite reconnect loop.
