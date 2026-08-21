# Issue #1030: Reference Link Auditing Pipeline (Phase 18.1)

**Type:** Feature / Quality Assurance  
**Component:** `build/check_doc_links.pl`, `tests/unit_doc_link_auditor.t`, `documentation/`  
**Assignee:** jmrenouard  
**Labels:** `documentation`, `links`, `integrity`, `audit`, `qa`  

## Goal
To guarantee documentation integrity across releases and prevent broken links or orphaned references across the MySQLTuner-perl repository.

## Description & Objectives
Phase 18.1 specifies:
1. `build/check_doc_links.pl`: Pure Perl documentation reference linter that:
   - Recursively parses all `.md` files in `documentation/`, `.agent/`, and the root repository directory (`README.md`, `USAGE.md`, `INTERNALS.md`, `ROADMAP.md`, `RULES.md`, `TESTS.md`, `MEMORY_DB.md`).
   - Extracts all local markdown links and resolves them relative to file locations.
   - Verifies target existence on disk and detects dead links.
2. Integration into pre-commit and automated test suites.
3. Dedicated TAP test suite `tests/unit_doc_link_auditor.t`.

## Implementation Details
- Implemented `build/check_doc_links.pl` in pure Perl using standard Core modules (`File::Find`, `File::Spec`, `File::Basename`, `Cwd`).
- Audited all relative file references across 100+ documentation markdown files.
- Integrated automated verification into test suite.

## Verification
- Run `perl build/check_doc_links.pl`
- Run `prove tests/unit_doc_link_auditor.t`

## Acceptance Criteria
- [x] `build/check_doc_links.pl` implemented in pure Perl (Core only).
- [x] All relative local documentation links verified across repo.
- [x] TAP test suite `tests/unit_doc_link_auditor.t` passing.
