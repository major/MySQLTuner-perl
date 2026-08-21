# Issue #1034: SQL Error Trace Logging & Query Safety (Phase 23.3)

**Type:** Feature / Logging & Observability  
**Component:** `mysqltuner.pl`, `tests/unit_sql_trace_logging.t`  
**Assignee:** jmrenouard  
**Labels:** `sql`, `logging`, `trace`, `diagnostics`, `engine`  

## Goal
To capture and record SQL execution anomalies and permission rejections to an internal trace log array/file instead of silent suppression, aiding DBAs in diagnosing grant or privilege restrictions.

## Description & Objectives
Phase 23.3 specifies:
1. `mysqltuner.pl` improvements:
   - Introduce global trace buffer `@main::sql_traces` and `--sqllog` / `--sqltrace` support.
   - Implement `log_sql_trace($query, $error_msg, $status_code)`.
   - Implement `get_sql_traces()` to retrieve recorded traces for programmatic export (JSON/MCP).
   - Implement `format_sql_trace_report()` to render structured diagnostic traces.
2. Zero non-core dependencies and strict single-file architecture.
3. Dedicated TAP test suite `tests/unit_sql_trace_logging.t`.

## Implementation Details
- Added `log_sql_trace()`, `get_sql_traces()`, `clear_sql_traces()`, and `format_sql_trace_report()` to `mysqltuner.pl`.
- Integrated trace capturing into query execution paths.

## Verification
- Run `prove tests/unit_sql_trace_logging.t`

## Acceptance Criteria
- [x] `log_sql_trace`, `get_sql_traces`, `clear_sql_traces` implemented in `mysqltuner.pl`.
- [x] Trace buffer records failed queries with timestamps, errors, and status codes.
- [x] TAP test suite `tests/unit_sql_trace_logging.t` passing.
