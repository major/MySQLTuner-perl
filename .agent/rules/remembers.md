---
trigger: always_on
description: Permanent storage for session-discovered patterns and rules.
category: governance
---
# **🧠 REMEMBERS & DYNAMIC RULES**

## 🧠 Rationale

High-density agentic development requires a persistent memory of emerging patterns and constraints that haven't yet been formalized in the core constitution.

## 🛠️ Implementation

If new rules are identified during a session, invoke the `/hey-agent` workflow to formalize them in this file.

**REMEMBER LOG:**

- Rule: Documentation updates (`docs:`) following Conventional Commits can skip manual `@Changelog` entry if they are synchronization-only.
- Rule: New tests MUST have a `test:` entry in the `@Changelog`.
- Rule: Test script or infrastructure updates MUST have a `ci:` entry in the `@Changelog`.
- Rule: `Makefile` and `build/*` changes MUST be traced in the `@Changelog`.
- Rule: HTML reports MUST be self-sufficient, embedding all relevant logs (Docker, DB injection, etc.) and placing MySQLTuner output at the bottom for consolidated sharing.
- Rule: Testing MUST encompass 3 specific scenarios: Standard (--verbose), Container (--verbose --container), and Dumpdir (--verbose --dumpdir=dumps).
- Rule: HTML reports MUST include a horizontal scenario selector for tripartite test cases.
- Rule: All test infrastructure logs (docker start, db injection, container logs, container inspect) MUST be captured and linked in HTML reports.
- Rule: HTML reports MUST contain a "Reproduce" section with the full sequence of commands.
- Rule: Kernel tuning recommendations MUST be skipped in container mode or when running in Docker.
- Rule: Changelog entries MUST be ordered by category: `feat`, `fix`, `docs`, `ci`, then others (`test`, `chore`).
- Rule: The `/git-flow` workflow MUST always be preceded by a successful `/release-preflight` execution.
- Rule: The `examples/` directory MUST only retain the 10 most recent laboratory execution results to optimize storage.
- Rule: Each version MUST have a detailed release notes file in `/releases/vX.Y.Z.md` generated via `/release-notes-gen` before triggering a release workflow.
- Rule: The `.agent/README.md` MUST be synchronized using `/doc-sync` after any modification to governance assets (Rules/Skills/Workflows).
- Rule: The `.agent/README.md` MUST be automatically updated via `/doc-sync` during the `/hey-agent` lifecycle.
- Rule: Report files (HTML and logs) MUST NOT contain negative keywords like `error`, `warning`, `fatal`, or `failed` (except when explicitly documenting expected failures).

## ✅ Verification

- Periodically migrate stabilized rules from here to `04_best_practices.md` using the `/hey-agent` workflow.
