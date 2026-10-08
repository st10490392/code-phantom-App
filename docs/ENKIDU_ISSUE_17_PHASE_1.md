# Issue 17: branding and customer signals first

Phase 1 uses the proposed CPT ENKIDU EA public name for the owner command centre. CodePhantom remains the app name. Existing GILGAMESH routes, entitlements, bindings and broker evidence identifiers are preserved. QIN is internal; no AI/autonomy claim is added. V5 observation, research, gates, evidence and promotion are unchanged.

Signals use CPT Market Direction / CPT Market Update, readable lifecycle labels, Entry/SL/TP and optional supported TP2, timeframe and UTC timestamps. Observations are explicitly separate from broker execution. Unknown outcomes and cancelled signals do not inflate win rate; breakevens are outside its denominator. Statistics describe the latest 200 loaded signals, not all-time or broker performance. Missing resolved outcomes/R observations show no-data copy. Signal load failures offer Retry without exposing raw exceptions; populated lists support pull-to-refresh.

The private command centre now requires admin.system in app routing, navigation, dashboard and the paired backend. An EA entitlement alone no longer exposes it. Backend administrators can inspect the fleet; direct service calls remain user-scoped by default. Customer signal reads enforce market/release visibility before pagination and return 404 for inaccessible individual signals. Legacy SIGNALS subscribers may see unscoped published signals only. Cancellation joins the existing transactional, unique-per-signal push outbox and entitlement fanout. No SL-move advice is introduced without an approved deterministic policy and broker evidence.

## Validation and staging

Flutter analyze is clean; all 250 app tests pass. The paired backend passes 169 unit/integration tests and 111 disposable PostgreSQL tests, including privacy, market filtering, cancellation idempotency and admin command-centre authorization. Backend lint has four existing warnings and no errors. No remote database or flags were changed.

The staging build script verifies HTTPS /health reports staging before producing debug APK and release PWA. Its build manifest records the source SHA and APK digest. The existing staging backend predates these PRs: artifacts are review builds, not proof of a matched runtime rollout. Apply the paired backend migration before running that backend in any separately authorized staging rollout. Preserve all existing push rows; rollback code first and keep the expanded constraint.

## Next phase and blockers

The separately licensed CodePhantom Trader client (ENKIDU Forex/CFD and independent Antagonistic synthetics service selections) is the next phase of issue 17. It is not created or licensed here. #15 owner/account proof, deterministic risk handshake, runtime evidence attachment, deployment identity, FCM provisioning and physical-device notification acceptance remain prerequisites. Brand/trademark approval remains pending. No production deployment, merge, broker order or MT5 Algo Trading activation is authorized or performed.
