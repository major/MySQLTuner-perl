# Issue #1021: MySQL Boolean Normalization Engine (Phase 24)

**Type:** Feature / Architecture Refactoring  
**Component:** `mysqltuner.pl`, `tests/unit_boolean_normalization.t`  
**Assignee:** jmrenouard  
**Labels:** `engine`, `normalization`, `boolean`, `quality`  

## 🎯 Description & Objectives
MySQL, MariaDB, and Percona Server represent boolean configurations using disparate representations across engine versions and subsystems:
- `ON` / `OFF`
- `1` / `0`
- `YES` / `NO` (e.g. `SHOW SLAVE STATUS`, `information_schema.TABLES`)
- `TRUE` / `FALSE`
- `ENABLED` / `DISABLED` (e.g. `performance_schema.setup_instruments`)

This phase implements a central, high-performance boolean normalization engine in `mysqltuner.pl` (`normalize_mysql_bool`, `is_mysql_true`, `is_mysql_false`, `format_mysql_bool`) and replaces fragile ad-hoc regexes with unified helper invocations.

## 🧪 Acceptance Criteria
- [x] Standard subroutines `normalize_mysql_bool`, `is_mysql_true`, `is_mysql_false`, `format_mysql_bool` defined in `mysqltuner.pl`.
- [x] Handles undefined values, numeric 0/1, strings `ON`/`OFF`, `YES`/`NO`, `TRUE`/`FALSE`, `ENABLED`/`DISABLED` case-insensitively.
- [x] Comprehensive TAP unit test `tests/unit_boolean_normalization.t` covering all representations, edge cases, and helper methods.
- [x] Core diagnostic blocks refactored to use `is_mysql_true` / `is_mysql_false`.
