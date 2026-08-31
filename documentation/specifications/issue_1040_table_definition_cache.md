# Issue #1040: Table Definition Cache & Open Tables Saturation Audit (Phase 34)

**Type:** Feature / Engine Diagnostic  
**Component:** `mysqltuner.pl`, `tests/unit_table_definition_cache.t`  
**Assignee:** jmrenouard  
**Labels:** `engine`, `cache`, `table_definition_cache`, `thrashing`, `performance`  

## Goal
To audit database `table_definition_cache` usage, detecting cache capacity saturation and frequent table definition eviction thrashing (`Opened_table_definitions`/sec) to optimize dictionary cache performance.

## Description & Objectives
Phase 34 specifies:
1. `mysqltuner.pl` improvements:
   - Implement `audit_table_definition_cache($table_definition_cache, $open_table_definitions, $opened_table_definitions, $uptime)`.
   - Calculate cache fill ratio (`$open_table_definitions / $table_definition_cache * 100`).
   - Calculate eviction rate (`$opened_table_definitions / $uptime`).
   - Flag saturation when fill ratio >= 90% and eviction rate indicates continuous table definition reloading (> 5 definitions/sec).
   - Recommend increasing `table_definition_cache` proportionally to prevent FRM/.SDI reload overhead.
2. Zero non-core dependencies and strict single-file architecture.
3. Dedicated TAP test suite `tests/unit_table_definition_cache.t`.

## Implementation Details
- Implemented `audit_table_definition_cache` in `mysqltuner.pl`.
- Added test coverage in `tests/unit_table_definition_cache.t`.

## Verification
- Run `prove tests/unit_table_definition_cache.t`

## Acceptance Criteria
- [x] `audit_table_definition_cache` implemented in `mysqltuner.pl`.
- [x] Accurate detection of table definition cache thrashing and saturation.
- [x] TAP test suite `tests/unit_table_definition_cache.t` passing.
