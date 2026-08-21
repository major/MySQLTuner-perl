# Issue #1036: Unit Test Decomposition: `test_issue_863.t` (Phase 26.2)

**Type:** Refactoring / Unit Test Decomposition  
**Component:** `tests/test_issue_863.t`  
**Assignee:** jmrenouard  
**Labels:** `test`, `refactoring`, `decomposition`, `subtests`, `cpanel`, `quality`  

## Goal
To decompose unstructured top-level assertions in `tests/test_issue_863.t` into structured, human-assimilable subtests according to the project constitution.

## Description & Objectives
Phase 26.2 specifies:
1. Refactoring `tests/test_issue_863.t`:
   - Decomposing into discrete `subtest` blocks:
     1. cPanel environment with `skip_name_resolve=OFF` (compliant).
     2. cPanel environment with `skip_name_resolve=ON` (non-compliant warning & KB reference).
     3. Standard environment with `skip_name_resolve=OFF` (performance recommendation).
     4. Standard environment with `skip_name_resolve=ON` (compliant).
   - Clear test plans per subtest (`plan tests => N`).
2. Zero non-core dependencies and 100% PASS rate.

## Implementation Details
- Refactored `tests/test_issue_863.t` with structured Test::More subtests covering all 4 matrix permutations.

## Verification
- Run `prove tests/test_issue_863.t`

## Acceptance Criteria
- [x] Unstructured test split into 4 human-assimilable subtests.
- [x] Explicit subtest plans and descriptive titles added.
- [x] TAP test suite passing cleanly.
