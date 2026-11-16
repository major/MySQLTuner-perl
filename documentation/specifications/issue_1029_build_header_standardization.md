---
test_file: tests/unit_build_headers.t
---

# Issue #1029: Build Script Header Standardization (Phase 30.3)

**Type:** Refactoring / Code Quality  
**Component:** `build/*.pl`, `build/*.sh`, `build/check_build_headers.pl`, `tests/unit_build_headers.t`  
**Assignee:** jmrenouard  
**Labels:** `build`, `headers`, `standardization`, `clean-code`, `qa`  

## Goal
Standardize metadata headers across all build and tooling scripts in `build/` using a structured schema audited via `build/check_build_headers.pl`.

## Description & Objectives
To ensure maintainability, clear execution instructions, and traceability across the entire toolchain, Phase 30.3 specifies:
1. A standard metadata header format for all build scripts (`build/*.pl`, `build/*.sh`):
   - `Script:` Relative script path
   - `Description:` Concise summary of purpose
   - `Author:` Creator/Maintainer information
   - `Dependencies:` List of dependencies (Perl Core modules, Docker, etc.)
   - `Usage:` Exact invocation syntax and options
2. Static header validator `build/check_build_headers.pl` in pure Perl auditing all scripts in `build/`.
3. Dedicated TAP test suite `tests/unit_build_headers.t`.

## Implementation Details
- Formatted headers across all `build/*.pl` and `build/*.sh` scripts.
- Implemented static validator `build/check_build_headers.pl`.
- Created unit tests in `tests/unit_build_headers.t`.

## Verification
- Run `prove tests/unit_build_headers.t`

## Acceptance Criteria
- [x] All `build/*.pl` and `build/*.sh` scripts contain standard metadata headers.
- [x] Linter `build/check_build_headers.pl` verifies header compliance.
- [x] TAP test suite `tests/unit_build_headers.t` passing.
