# Issue #1032: Automated Changelog & Release Schema Quality Gate (Phase 19.1 & 19.3)

**Type:** Feature / CI/CD Quality Gate  
**Component:** `build/check_changelog_gate.pl`, `tests/unit_changelog_gate.t`, `Changelog`, `releases/`  
**Assignee:** jmrenouard  
**Labels:** `changelog`, `release`, `schema`, `quality-gate`, `ci`  

## Goal
To automate the syntactic, semantic, and ordering validation of `Changelog` entries and release artifacts in `releases/v*.md`.

## Description & Objectives
Phase 19 specifies:
1. `build/check_changelog_gate.pl`: Pure Perl validation script checking:
   - Valid Conventional Commit types (`chore`, `feat`, `fix`, `test`, `ci`, `docs`, `perf`, `refactor`, `style`) in Changelog and Release Notes.
   - Strict category ordering: `chore`, `feat`, `fix`, `test`, `ci`, followed by others.
   - Presence of issue references `(#\d+)` for traceability.
   - Validation that `releases/v<VERSION>.md` conforms to the standard release schema.
2. Integration into CI test runner and pre-commit checks.
3. Dedicated TAP test suite `tests/unit_changelog_gate.t`.

## Implementation Details
- Implemented `build/check_changelog_gate.pl` in pure Perl using standard Core modules.
- Added comprehensive checks for Changelog blocks and release notes markdown files.

## Verification
- Run `perl build/check_changelog_gate.pl`
- Run `prove tests/unit_changelog_gate.t`

## Acceptance Criteria
- [x] `build/check_changelog_gate.pl` implemented in pure Perl (Core only).
- [x] Changelog and Release Notes schema and ordering audited.
- [x] TAP test suite `tests/unit_changelog_gate.t` passing.
