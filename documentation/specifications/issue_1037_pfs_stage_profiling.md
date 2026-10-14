# Issue #1037: Performance Schema Stage & Wait Event Profiling (Phase 31)

**Type:** Feature / Engine Diagnostic  
**Component:** `mysqltuner.pl`, `tests/unit_pfs_stage_profiling.t`  
**Assignee:** jmrenouard  
**Labels:** `pfs`, `performance_schema`, `profiling`, `stages`, `waits`, `engine`  

## Goal
To audit database execution bottlenecks by analyzing Performance Schema stage and wait event summaries (`events_stages_summary_global_by_event_name` / `events_waits_summary_global_by_event_name`), detecting excessive temporary table creation on disk, sorting bottlenecks, and lock waits.

## Description & Objectives
Phase 31 specifies:
1. `mysqltuner.pl` improvements:
   - Implement `audit_pfs_stage_profiling($pfs_stages_ref, $pfs_waits_ref)`.
   - Detect high-latency stage events: `stage/sql/Creating tmp table`, `stage/sql/Sorting result`, `stage/sql/Sending data`.
   - Detect high-latency wait events: `wait/synch/mutex/innodb/*`, `wait/io/file/innodb/*`.
   - Provide structured recommendations when excessive wait latencies or disk temp table stages are detected.
2. Zero non-core dependencies and strict single-file architecture.
3. Dedicated TAP test suite `tests/unit_pfs_stage_profiling.t`.

## Implementation Details
- Implemented `audit_pfs_stage_profiling` in `mysqltuner.pl`.
- Added test coverage in `tests/unit_pfs_stage_profiling.t`.

## Verification
- Run `prove tests/unit_pfs_stage_profiling.t`

## Acceptance Criteria
- [x] `audit_pfs_stage_profiling` implemented in `mysqltuner.pl`.
- [x] Accurate stage event and wait bottleneck detection.
- [x] TAP test suite `tests/unit_pfs_stage_profiling.t` passing.
