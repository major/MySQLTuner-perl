---
test_file: tests/unit_ci_matrix.t
---

# Issue #1027: CI/CD Version Matrix Harmonization (Phase 28)

**Type:** Feature / CI Infrastructure  
**Component:** `build/ci_matrix.json`, `tests/unit_ci_matrix.t`, GitHub Actions workflows  
**Assignee:** jmrenouard  
**Labels:** `ci`, `matrix`, `mysql`, `mariadb`, `supported-versions`  

## Goal
Centralize and harmonize database version matrices across CI workflows and example generators via `build/ci_matrix.json` aligned with official LTS support policies.

## Description & Objectives
Previously, test matrices across GitHub Actions and example generators had discrepancies and tested legacy/EOL versions while omitting LTS releases (MySQL 8.4 LTS, MySQL 9.x Innovation, MariaDB 10.11 LTS, MariaDB 11.4 LTS).

This phase implements:
1. `build/ci_matrix.json`: Machine-readable centralized definition of supported and legacy database versions for CI, integration tests, and example generation.
2. Synchronizes version lists with `mysql_support.md` and `mariadb_support.md`.
3. Dedicated TAP test suite `tests/unit_ci_matrix.t` validating matrix consistency, JSON syntax, and alignment with support policies.

## Implementation Details
- Created `build/ci_matrix.json` defining active versions.
- Aligned matrices with `mysql_support.md` and `mariadb_support.md`.
- Implemented unit tests in `tests/unit_ci_matrix.t`.

## Verification
- Run `prove tests/unit_ci_matrix.t`

## Acceptance Criteria
- [x] Machine-readable `build/ci_matrix.json` created with supported MySQL and MariaDB LTS & current releases.
- [x] TAP test suite `tests/unit_ci_matrix.t` validating JSON schema and version matching.
