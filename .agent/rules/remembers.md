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

- Rule: Report diagnostic anomalies (Perl warnings, SQL errors) in `POTENTIAL_ISSUES` at root, including the path to the relevant `execution.log`.
- Rule: Cleanup `POTENTIAL_ISSUES` file as soon as the reported issue is handled, tested, or fixed.
- Rule: Audit `execution.log` for "✘ Performance_schema should be activated." and report it in `POTENTIAL_ISSUES`.
- Rule: Automated test example generation (via `run-tests`) MUST only target "Supported" versions of MySQL and MariaDB as defined in `mysql_support.md` and `mariadb_support.md`.
- Rule: File links in artifacts MUST be cleaned up to remove workstation-specific absolute paths (e.g., replace `file:///home/jmren/GIT_REPOS/` with `file:///`).

## ✅ Verification

- Periodically migrate stabilized rules from here to `04_best_practices.md` using the `/hey-agent` workflow.
