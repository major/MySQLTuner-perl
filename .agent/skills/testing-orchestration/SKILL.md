---
trigger: explicit_call
description: Knowledge on how to run, orchestrate, and validate tests in the MySQLTuner project.
category: skill
---
# Testing Orchestration Skill

## 🧠 Rationale

Centralizing test execution knowledge ensures consistency across different workflows (CI, manual testing, git-flow) and provides a single source of truth for test patterns and mandates.

## 🛠️ Implementation

### 1. Test Discovery & Execution

MySQLTuner uses Perl's `Test::More` framework. Tests are located in the `tests/` directory and have the `.t` extension.

| Method | Command | Context |
| :--- | :--- | :--- |
| **Prove (Standard)** | `prove -r tests/` | Fastest way to run all unit tests recursively. |
| **Prove (Verbose)** | `prove -v -r tests/` | Use for debugging specific failures. |
| **Makefile** | `make unit-tests` | Standardized entry point for CI/CD. |
| **Docker Lab** | `make test-it` | Run tests against multiple DB configurations (Legacy/Modern). |

### 2. Tripartite Testing Standard

For any logic change, testing MUST encompass:

1. **Standard**: `--verbose`
2. **Container**: `--container`
3. **Dumpdir**: `--dumpdir=dumps`

- **Verification Mandates**:
  - Zero Regression: 100% pass rate required.
  - **Clean Reports**: Output files (HTML/logs) MUST NOT contain `error`, `warning`, `fatal`, or `failed` keywords.
  - Infrastructure Logs: Capture Docker logs, DB injections, etc.
- **Reproducibility**: Every test run MUST be reproducible via provided commands or scripts.

## ✅ Verification

- Run `prove -r tests/` to verify the testing environment.
- Validate that `make unit-tests` executes the expected suite.
