# Coding-agent instructions

Before substantial work, read docs/MASTER_DEVELOPMENT_BRIEF.md, CURRENT_STATE.md if present, README.md, and relevant module/API documentation.

Follow the mandatory Orient → Inspect → Audit → Plan → Implement → Test → Review → Document → Deliver workflow in the master brief.

This is the CodePhantom Flutter client. The backend is authoritative for authorization, licensing, entitlements, ownership and sensitive business rules. Preserve existing architecture and user changes. Do not over-engineer or rebuild modules. Never invent test results.

Do not deploy, apply hosted migrations, rotate production secrets, modify customer data/licences, enable live trading/remote commands/message delivery, or merge to a protected branch without explicit owner approval. Do not use destructive Git operations. Keep mocks separate from live services.

At completion, report exact branch/commit, files changed, commands and actual test results, remaining risks, owner actions and next roadmap priority.
