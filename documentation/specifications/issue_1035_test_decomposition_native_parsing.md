# Issue #1035: Unit Test Decomposition: `repro_native_parsing.t` (Phase 26.1)

**Type:** Refactoring / Unit Test Decomposition  
**Component:** `tests/repro_native_parsing.t`  
**Assignee:** jmrenouard  
**Labels:** `test`, `refactoring`, `decomposition`, `subtests`, `quality`  

## Goal
To decompose monolithic test assertions in `tests/repro_native_parsing.t` into structured, human-assimilable subtests according to the project constitution.

## Description & Objectives
Phase 26.1 specifies:
1. Refactoring `tests/repro_native_parsing.t`:
   - Decomposing into discrete `subtest` blocks:
     1. Memory parsing (`/proc/meminfo` physical and swap calculations).
     2. Kernel swappiness and VM parameter parsing.
     3. System info and name resolution (`/etc/resolv.conf`) parsing.
     4. Perl syntax and execution hygiene.
   - Clear test plans per subtest (`plan tests => N`).
2. Zero non-core dependencies and 100% PASS rate.

## Implementation Details
- Refactored `tests/repro_native_parsing.t` with structured Test::More subtests.

## Verification
- Run `prove tests/repro_native_parsing.t`

## Acceptance Criteria
- [x] Monolithic test split into 4 human-assimilable subtests.
- [x] Explicit subtest plans and descriptive titles added.
- [x] TAP test suite passing cleanly.
