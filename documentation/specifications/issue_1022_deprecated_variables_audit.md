# Issue #1022: Deprecated System Variables & Synonyms Audit (Phase 25)

**Type:** Feature / Diagnostic Rule Engine  
**Component:** `mysqltuner.pl`, `tests/unit_deprecated_vars_audit.t`  
**Assignee:** jmrenouard  
**Labels:** `diagnostic`, `variables`, `deprecated`, `tuning`, `recommendations`  

## 🎯 Description & Objectives
Modern MySQL (8.0, 8.4, 9.x) and MariaDB (10.11, 11.4+) have eliminated dozens of legacy system variables and obsolete synonyms. When legacy configuration files contain these variables, the server either logs deprecation notices or fails to parse them on startup.

This phase implements a dedicated diagnostic audit routine `audit_deprecated_variables()` in `mysqltuner.pl` that inspects loaded server variables and emits actionable modernization guidance:
1. `log_slow_queries` -> `slow_query_log`
2. `table_cache` -> `table_open_cache`
3. `tx_isolation` (MySQL 8.0+ / MariaDB 11.1+) -> `transaction_isolation`
4. `query_cache_size` / `query_cache_type` (MySQL 8.0+) -> Remove (Query cache removed)
5. `default_authentication_plugin` (MySQL 8.4+) -> `authentication_policy`
6. `innodb_file_format` / `innodb_large_prefix` (MySQL 8.0+) -> Remove (Barracuda is default)

## 🧪 Acceptance Criteria
- [x] Dedicated diagnostic subroutine `audit_deprecated_variables()` implemented in `mysqltuner.pl`.
- [x] Correct version-gating ensuring legacy variables are only flagged when obsolete for the target DB version.
- [x] Recommendations pushed to `@generalrec` and structured in `$result{'Deprecated_Variables'}` for JSON/HTML reports.
- [x] Comprehensive TAP unit test `tests/unit_deprecated_vars_audit.t` validating all deprecation rules.
