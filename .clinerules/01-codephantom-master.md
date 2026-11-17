# CodePhantom Cline rules

Always read AGENTS.md and docs/MASTER_DEVELOPMENT_BRIEF.md before substantial work. Treat the master brief as the durable product/engineering contract; treat CURRENT_STATE.md and module docs as implementation status that must be checked against current code.

This is the Flutter client. Backend authorization, account ownership, entitlements and licence validity are authoritative. Do not move trading strategy or execution logic into this app. Keep PH-SIGNALS and PH-EA separate. Preserve the current architecture and user changes; no broad rewrites or speculative complexity.

Every substantial task must inspect Git state first, audit the real implementation, plan the smallest safe change, implement, run relevant tests/analyze/build, inspect the final diff, update docs/roadmap and report exact evidence.

Never deploy, run hosted migrations, rotate production secrets, mutate customer records/licences, enable live trading/EA commands/external delivery, or merge protected branches without explicit approval. Never use destructive Git commands. Never claim unrun tests passed.
