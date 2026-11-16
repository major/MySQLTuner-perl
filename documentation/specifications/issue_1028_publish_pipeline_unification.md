---
test_file: tests/unit_release_validation.t
---

# Issue #1028: Publish Pipeline Unification (Phase 29)

**Type:** Feature / Release Pipeline  
**Component:** `build/validate_release.pl`, `build/validate_release.sh`, `Makefile`, `tests/unit_release_validation.t`  
**Assignee:** jmrenouard  
**Labels:** `release`, `publish`, `validation`, `docker`, `ci`  

## Goal
Unify pre-publish validation across CI workflows and local environments through a single script `build/validate_release.pl` in pure Perl to enforce release integrity.

## Description & Objectives
Previously, pre-publish validation was split and duplicated between GitHub Actions workflows (`docker_publish.yml` and `publish_release.yml`) and local shell scripts.

This phase implements:
1. `build/validate_release.pl`: Pure Perl unified pre-publish validation script checking:
   - Presence of all critical release artifacts (`mysqltuner.pl`, `CURRENT_VERSION.txt`, `Changelog`, `releases/v<VERSION>.md`, `Dockerfile`, `Makefile`, `USAGE.md`, `README.md`)
   - Strict version synchronization across all 6 reference locations
   - Non-empty release notes and compliance with Conventional Commits
2. `build/validate_release.sh`: Sourcing wrapper for CI workflows and Makefile.
3. Makefile deprecation notice for local `publishtodockerhub.sh` in favor of validated CI workflows.
4. Comprehensive TAP unit test `tests/unit_release_validation.t`.

## Implementation Details
- Implemented `build/validate_release.pl` and `build/validate_release.sh`.
- Consolidated artifact and version checks into a single runner.
- Added unit tests in `tests/unit_release_validation.t`.

## Verification
- Run `prove tests/unit_release_validation.t`

## Acceptance Criteria
- [x] `build/validate_release.pl` and `build/validate_release.sh` implemented in pure Perl/POSIX.
- [x] All 6 version references and critical files audited.
- [x] TAP test suite `tests/unit_release_validation.t` passing.
