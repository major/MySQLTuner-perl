---
test_file: tests/unit_versions.t
---
# Specification: Warning Elimination & Version Comparison Optimization

## Goal
Eliminate Perl runtime uninitialized value warnings during execution (specifically in version checks, InnoDB log analysis, and MariaDB detection paths) and optimize the version comparison routines by caching parsed version components.

## Requirements
1. **Version Caching & Optimization**:
   - Cache the parsed version components (major, minor, micro) in lexical variables `$cached_v_maj`, `$cached_v_min`, `$cached_v_mic` based on `$myvar{'version'}`.
   - Refactor `mysql_version_ge()`, `mysql_version_le()`, and `mysql_version_eq()` to use cached version components instead of performing regex parsing on every invocation.
   - Guard comparison helper parameters (`$maj`, `$min`, `$mic`) to prevent uninitialized value warnings when comparison arguments are undefined.
   - Guard `$myvar{'version'}` regex match inside `validate_mysql_version()` to avoid matching on undefined variables.

2. **InnoDB Analysis Guards**:
   - Guard `$mycalc{'innodb_log_size_pct'}` and `$myvar{'innodb_log_file_size'}` with definedness operators (`// 0`) before using them in calculations or printing output within `mysql_innodb()`.
   - Prevent potential uninitialized warnings during multiplication or printing in the InnoDB log size checks block.

3. **MariaDB Detection Guards**:
   - Guard `$myvar{'version_comment'}` and `$myvar{'version'}` checks using the definedness default operator (`// ''`) inside the parallel replication and query cache plugin check blocks.
   - Guard the `infoprint` statement in `security_recommendations()` where version and version comment are printed.

## Verification
- Run `make unit-tests` to ensure that all unit tests execute and pass cleanly.
- The test output audit gate must report 0 runtime uninitialized value warnings from the version checks or InnoDB code path.
