# CodePhantom Master Development Brief

Product: CodePhantom Technologies  
Tagline: Engineering intelligent systems  
Status: Living brief. Update when verified architecture or owner decisions change.

## Product vision
CodePhantom is a modular technology platform, not a single trading bot. Its customer-facing centre is the CodePhantom application and website, supported by a secure backend and separately operated specialist engines.

The ecosystem includes:
- CodePhantom App: customer and owner-facing mobile/web experience for accounts, products, licences, signals, scanner services, EA monitoring, administration and notifications.
- CodePhantom Backend: authoritative API, identity integration, permissions, licensing, entitlements, customer/account data, integrations and audit records.
- CPT-Scanner: independent market-scanning/setup-generation components publishing through explicit contracts.
- CodePhantom EA: separately operated MetaTrader execution/monitoring components. Trading execution logic must not be moved into the app or general API.
- PHANTOM TRADERS: manual-trading companion/indicator. Keep it focused on understandable, actionable signals; do not over-engineer it or merge it into automated execution without an explicit product decision.
- Gilgamesh and QIN: separate strategy/research engines. Experimental outputs must be validated before promotion to customer-facing or live-trading use.
- AEGIS and SPECTRE: separate future security/assistant systems with explicit integration boundaries.

This repository is the Flutter application. It owns presentation, client-side state, navigation, secure client storage and API integration. It is not the source of truth for authorization, entitlements, licensing validity, account ownership, trading decisions or execution.

## Architecture principles
- Preserve existing Flutter architecture, feature boundaries, Riverpod providers, GoRouter routing, domain models, service interfaces and design system unless a verified reason requires change.
- Extend existing implementations instead of replacing modules or introducing parallel abstractions.
- Keep UI, domain and data responsibilities separated.
- Backend is authoritative for permissions, licence status, entitlements, account ownership, device binding and sensitive business rules. Client checks are UX only.
- Use secure storage for secrets/session tokens according to existing implementation. Never hardcode secrets, private keys, broker credentials or production endpoints with credentials.
- Keep development/staging/production configuration explicit. Never silently point development builds at production.
- If an API contract changes, update backend contract, client implementation, tests and docs together.
- Preserve accessibility, responsive layouts, loading/empty/error states and clear feedback.
- Avoid speculative dependencies, needless abstractions, unrelated refactors and over-engineering.

## Product and security invariants
1. PH-SIGNALS and PH-EA are distinct products/entitlements. Access to one never grants the other.
2. Scanner, Signals and EA functionality remain separately permissioned and entitlement-gated.
3. Owner/admin screens require backend authorization as well as UI gating.
4. Never expose API keys, integration secrets, plaintext licence keys or authentication tokens beyond one-time display/secure handoff.
5. Never log secrets, passwords, tokens or full licence keys.
6. No live execution, remote EA commands, signal publishing or customer-impacting operation may be enabled merely because a UI control exists.
7. Keep mocks clearly identified and restricted to tests/demos. Never present mock data as live customer data.
8. Do not alter commercial plan semantics, prices, bundle contents, expiry policy or customer licences without explicit owner approval.
9. Existing customers and installed clients must not be broken by an unannounced API or credential migration.
10. No production deployment, hosted migration, production secret rotation, customer licence mutation or live trading activation without explicit approval.

## Mandatory workflow for every substantial task
1. Orient: read this file, README, CURRENT_STATE.md if present, relevant docs and matching backend/API contracts.
2. Inspect: record branch, HEAD, working-tree state, existing changes and test commands. Never assume prior reports describe current code.
3. Audit: trace implementation end-to-end. Separate verified facts, inferences and unknowns.
4. Plan: state the smallest safe plan, affected files/contracts, migration needs, risks and tests. Ask only for genuinely ambiguous product/security decisions.
5. Implement: focused changes in existing architecture. Preserve unrelated user work.
6. Test: run focused tests, then relevant full test/analyze/build checks. Report exact commands/results; never claim unrun tests.
7. Review: inspect final diff for secrets, authorization gaps, regressions, generated files and unrelated edits.
8. Document: update CURRENT_STATE.md, brief, roadmap and relevant module docs when verified status or decisions change.
9. Deliver: changed files, branch/commit, tests, limitations, owner actions and rollback considerations.
10. Continue: identify next priority from roadmap, but do not begin a risky new scope without required approval.

## Git and change preservation
- Begin with git status --short --branch, git branch --show-current and git log -1 --oneline.
- Never run destructive commands such as reset --hard, clean, blind stash/rebase, force push or history rewrite.
- Do not discard, overwrite, stage or reformat unrelated user changes.
- Use dedicated feature branches for substantial changes.
- Inspect git diff and staged diff; stage only task-related files.
- Do not merge, push, deploy or alter protected/default branches without explicit authorization for that action.

## Testing and evidence
- Use existing test frameworks and scripts.
- Add regression tests for bugs and security boundaries, including denial paths.
- Do not weaken tests or change assertions merely to obtain a green run.
- Distinguish local tests, CI, staging and production verification.
- Passing client tests do not prove backend authorization or live integration correctness.

## Owner approval boundaries
Cline may inspect, document, add tests, implement ordinary development changes on a feature branch, run local tests and prepare reviewable commits.

Stop and request explicit approval before hosted deployments/migrations, production key rotation/revocation, customer account/licence/entitlement/billing changes, enabling live signals/EA commands/trade execution/external message delivery, destructive operations or merging to protected/default branches.

Prior authorization does not automatically authorize a different production action or scope.

## Cross-repository coordination
Backend owns authoritative API/security/business rules. App consumes documented contracts. Scanner and EA are separate clients with scoped credentials and tenant/account authorization. When changing a shared contract, inspect both repositories and preserve compatibility. Do not duplicate backend business logic in Flutter.

## Documentation truth standard
Classify claims as verified in current source, verified by tests, staging-verified, production-verified, reported but not independently verified, planned or blocked. Do not treat old roadmap items or reports as current truth without checking. Keep this brief concise; implementation specifics belong in module docs.
