# Issue #1038: InnoDB Adaptive Hash Index (AHI) & Memory Partitions Audit (Phase 32)

**Type:** Feature / Engine Diagnostic  
**Component:** `mysqltuner.pl`, `tests/unit_innodb_ahi.t`  
**Assignee:** jmrenouard  
**Labels:** `innodb`, `ahi`, `adaptive_hash_index`, `partitions`, `memory`, `engine`  

## Goal
To audit InnoDB Adaptive Hash Index (AHI) efficiency, evaluating search hit ratios vs overhead, and identifying mutex contention on `btr_search_latch` to recommend optimal partition sizing (`innodb_adaptive_hash_index_parts`) or safe deactivation.

## Description & Objectives
Phase 32 specifies:
1. `mysqltuner.pl` improvements:
   - Implement `audit_innodb_ahi($ahi_enabled, $ahi_searches, $non_ahi_searches, $ahi_parts, $bp_instances)`.
   - Calculate AHI search ratio: `ahi_searches / (ahi_searches + non_ahi_searches) * 100`.
   - Detect low efficiency (<15% AHI hit ratio on active workloads) and recommend disabling AHI to free buffer pool memory and eliminate latch contention.
   - Detect single-partition bottleneck (`innodb_adaptive_hash_index_parts = 1`) on multi-core systems and recommend increasing partitions to match buffer pool instances (up to 8 or 16).
2. Zero non-core dependencies and strict single-file architecture.
3. Dedicated TAP test suite `tests/unit_innodb_ahi.t`.

## Implementation Details
- Implemented `audit_innodb_ahi` in `mysqltuner.pl`.
- Added test coverage in `tests/unit_innodb_ahi.t`.

## Verification
- Run `prove tests/unit_innodb_ahi.t`

## Acceptance Criteria
- [x] `audit_innodb_ahi` implemented in `mysqltuner.pl`.
- [x] Accurate AHI ratio calculation and partition recommendations.
- [x] TAP test suite `tests/unit_innodb_ahi.t` passing.
