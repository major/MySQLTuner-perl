---
trigger: after_test_run
description: Post-execution audit of laboratory logs to detect subtle regressions and diagnostic anomalies.
category: governance
---

# Specification: Advanced Test Log Auditing

## 1. Description

Every laboratory run (via `make test`, `test-it`, or `test_envs.sh`) generates artifacts in `examples/`. These logs contain critical diagnostic information (Perl `warnings`, SQL `errors`, shell script crashes) that might not trigger an exit code failure but indicate decreasing quality or potential bugs.

## 2. User Stories

- **As a Developer**, I want to be alerted to Perl `warnings` (e.g., "uninitialized value") even if the test passes.
- **As a Product Manager**, I want a centralized `POTENTIAL_ISSUES` file that tracks all subtle anomalies detected during automated or manual research.

## 3. Requirements

- **Post-Run Audit**: The agent must scan `examples/xxx/{Standard,Container,Dumpdir}/execution.log`.
- **Search Patterns**: Look for:
  - Perl `warnings`: `uninitialized value`, `possible typo`, `syntax error`.
  - Database `errors`: `FAIL Execute SQL`, `invalid login credentials`.
  - Shell `errors`: `command not found`, `terminated by signal`.
- **Centralized Tracking**: Log every anomaly in `POTENTIAL_ISSUES` at the project root.
- **Categorization**: Each entry must include:
  - Scenario (Standard/Container/Dumpdir)
  - Source file/log
  - Exact `error` string
  - Severity (Critical/`Warning`/Info)

## 4. Acceptance Criteria

- A `POTENTIAL_ISSUES` file exists if any anomaly is found.
- The rule is formalized in `remembers.md` and `04_best_practices.md`.
- No duplicated entries in `POTENTIAL_ISSUES` for the same lab run.
