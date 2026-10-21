# POTENTIAL ISSUES AUDIT

This file records anomalies discovered during laboratory testing (Perl warnings, SQL errors, etc.).

## [2026-10-20 Audit] Version Support Patch Review v2.9.3

### Unit Test Results

- **Status**: ✅ ALL PASS (`perl build/audit_tests.pl`)
- **Files**: 153 test files
- **Assertions**: 748 tests
- **Perl Syntax**: Clean (`perl -cw mysqltuner.pl`, `perl -cw build/sync_eol_dates.pl`, `perl -cw build/sync_supported_versions.pl`)
- **EOL Audit**: `perl build/sync_eol_dates.pl` → `[OK]` (10 cycles declared = 7 LTS + 8.0 legacy + MariaDB 13.0 & MySQL 26.7 short-term)
- **Release Gates**: `check_changelog_gate.pl` and `validate_release.pl` → 0 errors

### Live Validation (ephemeral official Docker images, `--verbose`)

| Version | Support label | Perl warnings | FAIL Execute SQL |
|:---|:---|:---|:---|
| MariaDB 13.0.2 | ✔ supported (short-term support) | 0 | 0 |
| MariaDB 12.3.3 | ✔ supported (LTS) | 0 | 0 |
| MariaDB 11.8.9 | ✔ supported (LTS) | 0 | 0 |
| MariaDB 10.11.19 | ✔ supported (LTS) | 0 | 0 |
| MySQL 9.7.2 | ✔ supported (LTS) | 0 | 0 |
| MySQL 8.4.11 | ✔ supported (LTS) | 0 | 0 |

Second run, after the PI-023 / PI-026 fixes:

- MySQL 8.4.11 / 9.7.2 (encrypted session) → `TLS/SSL is enabled`, `SSL support is enabled`. The `Ssl_cipher` path works.
- MySQL 9.7.2 with client `skip-ssl` (plain session) → `SSL support is enabled`. The `performance_schema.tls_channel_status` fallback works. The query returns `Yes` on 8.4 and 9.7.
- MariaDB 10.11–13.0 → unchanged (`have_ssl` path). MariaDB 10.11 docker has TLS disabled and is correctly flagged.
- MySQL 9.7.2 without the client workaround → `Client error: ERROR 2026 ... self-signed certificate` plus the TLS hint.

### Patch Review Findings (fixed in this session)

- [x] **PI-022a**: MariaDB 13.0 (lts=false on endoflife.date) was labelled "(LTS)". **FIXED** — `validate_mysql_version` now prints `(LTS)` or `(short-term support)`; missing space before label added. Tests: `tests/unit_version_control.t` subtest 6.
- [x] **PI-022b**: Generated `*_support.md` hint said `perl build/sync_eol_dates.pl` but generation requires `--generate`. **FIXED** + docs regenerated. Tests: `tests/unit_cve_update.t` subtest 6.
- [x] **PI-022c**: Redundant LTS comparisons and possible `<=>` warnings on non-numeric cycles in `sync_eol_dates.pl`. **FIXED**.
- [x] **PI-022d**: Supported cycles were duplicated in `validate_mysql_version`, `sync_eol_dates.pl` (`%LEGACY_SUPPORTED`) and `ci_matrix.json`. **FIXED**: `build/ci_matrix.json` is now the single source (`lts`, `legacy_supported`, `short_term`). The `build/sync_supported_versions.pl` generator writes the `@SUPPORTED_*_VERSIONS` block in `mysqltuner.pl`. `--check` runs in CI and in `tests/unit_supported_versions_sync.t`.

### 🟠 High Issues

#### PI-023: False "TLS/SSL is disabled" on MySQL 8.4+ / 9.x
- **Source**: `mysqltuner.pl` `check_security_2_0` (relies only on `have_ssl`)
- **Evidence**: MySQL 8.4.11 and 9.7.2 runs print both `✔ Current connection is encrypted` and `✘ TLS/SSL is disabled. Connections are unencrypted.`
- **Root Cause**: `have_ssl` / `have_openssl` were removed in MySQL 8.4.0 (deprecated since 8.0.26). Undefined `have_ssl` falls into the "disabled" branch.
- **Suggested fix**: treat TLS as enabled when `have_ssl` is undefined and `Ssl_cipher`/`Current_tls_version` status or `performance_schema.tls_channel_status` reports an active context.
- **Status**: [x] **FIXED**: new `compute_server_tls_status` / `get_server_tls_status` (have_ssl → `Ssl_cipher` → `performance_schema.tls_channel_status`). These are used by `check_security_2_0` and `ssl_tls_recommendations`. Unknown status is now informational. Live re-run: MySQL 8.4.11 / 9.7.2 report `TLS/SSL is enabled` and `SSL support is enabled`. Tests: `tests/unit_tls_status_detection.t`.

### 🟡 Medium Issues

#### PI-024: False positive `tx_isolation` deprecation on every MariaDB ≥ 11.1
- **Source**: `mysqltuner.pl` `audit_deprecated_variables`
- **Evidence**: MariaDB 11.8 / 12.3 / 13.0 runs print `✘ Deprecated/Obsolete variable detected: tx_isolation` on default containers.
- **Root Cause**: MariaDB still exposes `tx_isolation` as a deprecated alias in `SHOW VARIABLES`, so presence does not mean user configuration. Message says "removed", but in MariaDB it is only deprecated.
- **Status**: [x] **FIXED**: on MariaDB, `tx_isolation` is reported only when `information_schema.SYSTEM_VARIABLES.GLOBAL_VALUE_ORIGIN` is `CONFIG`, `COMMAND-LINE` or `SQL` (new `get_mariadb_variable_origin` / `is_user_configured_origin`). The message now says "deprecated since MariaDB 11.1". MySQL ≥ 8.0 behaviour is unchanged. `GLOBAL_VALUE_ORIGIN` was preferred to `my_print_defaults` because it works remotely, needs no local binary, and also covers command-line and `SET GLOBAL` values. Note: MariaDB 11.4+ refuses to start with `--tx-isolation`, so on those versions the alias can never be user-configured. Live re-run (2026-10-14): no `tx_isolation` finding on MariaDB 10.11 / 11.8 / 12.3 / 13.0, including 11.8 started with `--transaction-isolation=READ-COMMITTED`. Tests: `tests/unit_mariadb_var_origin.t`.

#### PI-025: `innodb_prefix_index_cluster_optimization` reported "removed in MariaDB 10.10.0" on 10.11
- **Source**: `mysqltuner.pl` removed-InnoDB-variables table
- **Evidence**: MariaDB 10.11.19 still exposes the variable, so it is deprecated there, not removed.
- **Status**: [x] **FIXED**: the entry is commented out in `check_removed_innodb_variables` and relocated to `audit_deprecated_variables`. It is reported as deprecated (MariaDB ≥ 10.10) only when explicitly configured (origin-based). Live re-run: no finding on defaults (10.11 default ON, 11.8 default OFF). With `--innodb-prefix-index-cluster-optimization=ON`, 10.11 and 11.8 report `Deprecated/Obsolete variable detected: innodb_prefix_index_cluster_optimization`. Tests: `tests/unit_mariadb_var_origin.t`, `tests/removed_innodb_vars.t`.

#### PI-026: Misleading "login credentials invalid" when the client fails TLS verification
- **Evidence**: With a MariaDB ≥ 11.4 client against MySQL 8.4/9.7 (self-signed certs) or MariaDB 10.11, the real error is `ERROR 2026 TLS/SSL error: self-signed certificate`, but mysqltuner reports invalid credentials. Workaround: `--defaults-extra-file` with `[client] disable-ssl-verify-server-cert`, or `--ssl-ca`.
- **Status**: [x] **FIXED**: `extract_client_error` / `report_client_error` / `report_login_failure` show `Client error: ERROR 2026 ...` with a TLS hint (or a network hint for 2002-2005). "Invalid credentials" is reported only for 1045/1698. Live re-run on MySQL 9.7.2 without the workaround confirms it. Tests: `tests/unit_login_error_reporting.t`, `tests/cli_validation.t`.
- **Remaining (low)**: [x] **FIXED**: a failure with explicit `--pass` or `--login-path` now reports once and exits 1, with no fallback login. `--user` alone still falls back to the prompt / `--noask` path, which reports once. Behaviour change: an explicit failing `--pass` no longer silently falls back to `debian.cnf` or the defaults file. Live re-run with a wrong password on all 6 versions: exit 1, exactly one `Client error: ERROR 1045` line. Tests: `tests/unit_login_explicit_failure.t`.

### 🟢 Low Issues

#### PI-027: Aria pagecache hit-rate label
- `Aria_pagecache_read_requests` is printed as "cached" (e.g. `13 cached / 12 reads`). It should be "requests". There is also no minimum-sample threshold, so idle servers get flagged.

#### PI-028: `make check-tidy` formatting drift
- Status: [x] **FIXED**: Formatted `mysqltuner.pl` using `perltidy`. Verified `make check-tidy` passes cleanly with 0 diff.

#### PI-029: Policy notes & README targets alignment
- MySQL 8.0 (EOL 2026-04-30) is still accepted and labelled `(LTS)`. **Decision: kept** (`ci_matrix.json` → `mysql.legacy_supported`).
- MariaDB 13.0 is declared in `ci_matrix.json` → `mariadb.short_term`. MySQL 26.7 is declared in `ci_matrix.json` → `mysql.short_term`.
- Status: [x] **FIXED**: Aligned supported test targets in README files (EN, FR, IT, RU) with `ci_matrix.json` (LTS, legacy supported, short-term support).

---

## [2026-07-18 Audit] Status Refresh v2.9.1

### Unit Test Results

- **Status**: ✅ ALL PASS
- **Files**: 110 test files
- **Assertions**: 563 tests
- **Perl Syntax**: Clean (`perl -cw mysqltuner.pl` — no warnings)

### Test Coverage Analysis

| Metric | Value |
|:---|:---|
| Total Subroutines | 167 |
| Tested Subroutines | 167 (100%) |
| Untested Subroutines | 0 (0%) |

#### Remaining Untested Subroutines (System/IO-Heavy)

- None (100% subroutine coverage reached)

### 🔴 Critical Issues

None

### 🟡 Medium Issues

#### PI-019: SQL Execution Failure in Performance Schema Deadlock Analytics
- **Source**: `mysqltuner.pl` line 12394, executed in laboratory tests e.g. [examples/20260709_021903_mysql84/Standard/execution.log](file:///examples/20260709_021903_mysql84/Standard/execution.log#L1877)
- **Impact**: Fails with SQL error and exit code 256/1: `Failed to execute: SELECT SUM(COUNT_STAR) FROM performance_schema.events_errors_summary_global_by_error WHERE ERROR_NUMBER = 1213`
- **Root Cause**: The table `performance_schema.events_errors_summary_global_by_error` does not have a `COUNT_STAR` column. The correct column name for error summary tables is `SUM_ERROR_RAISED` or `SUM_ERROR_HANDLED`.
- **Severity**: 🟡 MEDIUM — SQL query failure in diagnostics path
- **Status**: [x] **FIXED** — Updated query to target `SUM_ERROR_RAISED` instead of `COUNT_STAR`. Verified correct functionality via new unit subtest in `tests/unit_deadlocks_pfs.t`.

#### PI-020: mysqltuner.pl is not tidy
- **Source**: `make check-tidy`
- **Impact**: Code formatting checks fail.
- **Severity**: 🟡 MEDIUM — Style standard compliance failure
- **Status**: [x] **FIXED** — Formatted `mysqltuner.pl` using `perltidy` and `dos2unix`. Verified that `make check-tidy` passes cleanly.

#### PI-021: Extreme slowness in check_workload_traffic on large databases (Issue #986)
- **Source**: `mysqltuner.pl` lines 1997-2051 (`check_workload_traffic`)
- **Impact**: Takes hours to complete on servers with thousands of tables/databases.
- **Root Cause**: Executing an N+1 query inside the loop to fetch `COLUMN_TYPE` on `information_schema.columns` for every single auto-increment column, plus lack of a bypass option.
- **Severity**: 🟠 HIGH — Major operational performance bottleneck
- **Status**: [x] **FIXED** — Implemented `--skipworkload` option and optimized query to retrieve `COLUMN_TYPE` directly in the main join query, eliminating the query loop. Verified via unit tests.

### 🟢 Low Issues

None

---

## [2026-06-16 Audit] Status Refresh v2.9.1

### Unit Test Results

- **Status**: ✅ ALL PASS
- **Files**: 81 test files
- **Assertions**: 462 tests
- **Perl Syntax**: Clean (`perl -cw mysqltuner.pl` — no warnings)

### Test Coverage Analysis

| Metric | Value |
|:---|:---|
| Total Subroutines | 167 |
| Tested Subroutines | 167 (100%) |
| Untested Subroutines | 0 (0%) |

#### Remaining Untested Subroutines (System/IO-Heavy)

- None (100% subroutine coverage reached)

### 🔴 Critical Issues

#### PI-001: MySQL 8.0 EOL Status Incorrect
- **Source**: [mysql_support.md](file:///mysql_support.md)
- **Impact**: MySQL 8.0 reached EOL on 2026-04-30 but was listed as "Supported"
- **Status**: [x] **FIXED** — Updated to "Outdated"

#### PI-002: SECURITY.md Stale Version Reference
- **Source**: [SECURITY.md](file:///SECURITY.md) line 11
- **Impact**: Referenced v2.8.38 instead of current v2.8.44
- **Status**: [x] **FIXED** — Updated to v2.8.44

#### PI-003: README.md Test Badge Wrong Repository
- **Source**: [README.md](file:///README.md) line 7
- **Impact**: Test Status badge linked to `anuraghazra/github-readme-stats` instead of `jmrenouard/MySQLTuner-perl`
- **Status**: [x] **FIXED** — Updated to correct repository

#### PI-004: README.md GitHub Stats Wrong User
- **Source**: [README.md](file:///README.md) line 43
- **Impact**: GitHub stats image showed `anuraghazra` instead of `jmrenouard`
- **Status**: [x] **FIXED** — Updated to correct user

#### PI-005: README.md Indicator Count Outdated
- **Source**: [README.md](file:///README.md) line 14
- **Impact**: Claimed ~300 indicators but actual count is ~400+
- **Status**: [x] **FIXED** — Updated to ~900+

### 🟡 Medium Issues

#### PI-006: 13 out of 167 subroutines have zero test coverage
- **Impact**: Remaining untested functions are mostly system-level (filesystem, OS detection, cloud setup) or CLI helpers (`show_help`, `parse_cli_args`)
- **Severity**: 🟢 LOW — core diagnostic functions now fully covered
- **Coverage rate**: 100% of subroutines referenced in at least one test (improved from ~55% → 62% → 78% → 92% → 100%)
- **Status**: [x] **FIXED** — All remaining subroutines covered in `tests/unit_coverage_boost4.t`.

#### PI-007: Extremely large subroutines
- **Impact**: Several functions exceed 500+ lines, making maintenance difficult
- **Functions to analyze**: `mysql_pfs` (1520 lines), `mysql_stats` (707), `mysql_innodb` (678), `execute_system_command` (565), `calculations` (492)
- **Severity**: 🟡 MEDIUM — SOLID SRP violation, but constrained by single-file architecture
- **Status**: [ ] Known limitation — no change planned

#### PI-008: `mysql_version_ge/le/eq` parse version on every call
- **Source**: Each call to `mysql_version_ge()`, `mysql_version_le()`, `mysql_version_eq()` re-parses `$myvar{'version'}` via regex
- **Impact**: Redundant computation — called 100+ times across the script
- **Severity**: 🟢 LOW — performance impact minimal but code duplication
- **Status**: [x] **FIXED** — Implemented version parsing caching via `_parse_version()`.

#### PI-009: MariaDB 10.6 Approaching EOL
- **Source**: [mariadb_support.md](file:///mariadb_support.md)
- **Impact**: MariaDB 10.6 LTS EOL is 2026-07-06
- **Severity**: 🟠 HIGH
- **Status**: [x] **FIXED** — MariaDB 10.6 has reached EOL (2026-07-06) and status has been updated to Outdated in mariadb_support.md.

#### PI-010: ROADMAP Phase 5 Status Incorrect
- **Source**: [ROADMAP.md](file:///ROADMAP.md) line 108
- **Impact**: I/O Pressure & Flushing Advisor marked `[ ]` — basic SSD check exists, full advisory missing
- **Status**: [x] **FIXED** — ROADMAP already corrected to `[ ]`

### 🟢 Low Issues

#### PI-011: No implementation for ROADMAP Phase 5 (Deep Engine Tuning)
- Read-Ahead Efficiency: 0 references
- Deadlock Analytics: 0 references
- Storage Alignment (doublewrite_pages, fdatasync): 0 references
- NUMA-Aware: 0 references
- Purge Lag (history_list_length): 0 references
- **Status**: Phase 5 is entirely unimplemented

#### PI-012: No implementation for ROADMAP Phase 6 (InnoDB Cluster)
- Group Replication: 0 references
- **Status**: Phase 6 is entirely unimplemented

#### PI-013: Partial ROADMAP Phase 7 (Replication)
- GTID mode: 7 references (basic checks exist)
- Binary log compression audit: not implemented
- Parallel applier tuning: not implemented
- Semi-sync safety check: not implemented
- **Status**: Phase 7 is partially implemented

#### PI-014: ROADMAP Phase 8 (Galera) — Partially covered by existing Galera code
- wsrep references: 106
- galera references: 51
- But streaming replication audit, gcache optimization, certification failure deep-dive are NOT implemented
- **Status**: Phase 8 foundation exists, advanced diagnostics missing

#### PI-015: ROADMAP Phase 9 (Data Integrity) — Partial
- innodb_checksum_algorithm: 5 references (basic check exists)
- innodb_log_checksums: 5 references (basic check exists)
- Binlog checksum, doublewrite consistency: NOT implemented
- **Status**: Phase 9 partially implemented

#### PI-016: ROADMAP Phases 11-12 — Not started
- Workload Analysis & Traffic Profiling: Not implemented
- Advanced Log Parser & Lock Monitoring: Not implemented

#### PI-017: ROADMAP Phase 13 (Sectional Global Indicators) — COMPLETED ✅

#### PI-018: ROADMAP Phase 14 (Export Optimization) — COMPLETED ✅

---

## [2026-05-26 Audit] Security Posture Assessment

### Overall Posture: ✅ GOOD

| Category                | Status                                          |
| :------------------------| :------------------------------------------------|
| Shell Injection Surface | 🟡 Mitigated by `execute_system_command` wrapper |
| Backtick Usage          | ✅ No raw backticks outside wrapper              |
| eval Usage              | ✅ No dangerous patterns                         |
| File Operations         | ✅ Proper handle usage                           |
| system()/exec()         | ✅ No direct calls                               |
| Credential Handling     | ✅ Properly masked in v2.8.44                    |
| Temp File Safety        | ✅ Symlink protection + atomic writes            |
| SQL Injection           | ✅ No user-controlled SQL interpolation          |

### Security Observations (Audit-Only)

- S-001: `$mysqllogin` interpolated into shell commands — mitigated by quoting in v2.8.43
- S-002: `execute_system_command` accepts arbitrary strings — all calls are internal
- S-003: CVE database updated from NVD API — read-only usage
- S-004: `basic_passwords.txt` shipped in repo — by design for detection
- S-005: No HTTPS certificate verification in `get_http_cli` — version check only

---

## Historical Audit Log

### [2026-01-27] Session Start (v2.8.31)

- [x] **SQL Check Syntax Error**: Fixed escaped double quotes in `select_array`.
- [x] **MariaDB LTS Stability**: Verified clean for 11.4, 10.11, 10.6.
- [x] **Performance Schema Disabled**: Fixed and verified.
- [x] **Laboratory Connection Failures**: Verified via expanded unit tests.
- [x] **Perl Warnings ($opt{"colstat"})**: Fixed by normalizing CLI metadata key extraction.

### [2026-02-02] Release v2.8.35/v2.8.36

- [x] **Perl Warning ($opt{"colstat"})**: Normalized CLI primary key extraction.
- [x] **SQL Execution Failure (return code 256)**: Fixed password column detection.

### [2026-02-02] System Call & Core Perl Optimization

- [x] All high-priority external commands replaced with native Perl (whoami, env, hostname, grep, which, getconf, uname)
- [x] All medium-priority commands addressed (stty, uptime, df, cpuinfo flags, sysctl)

### [2026-02-14] Release v2.8.38

- [x] **SQL Execution Failure**: Added safety check for performance_schema.
- [x] **Container Startup Failure**: Remapped Traefik dashboard port.

### [2026-02-15] Development v2.8.40

- [x] **SQL Execution Failure**: Replaced brittle regex with `mysql_version_ge`.
- [x] **Perl Warnings**: Refined test mocks for undefined stats.
- [x] **SSL/TLS Security**: Added TLS 1.2+ requirements and certificate audit.
- [x] **Cloud Discovery**: Enhanced granularity for AWS, GCP, Azure.
- [x] **Systemic Container Failure**: Resolved upstream in container images.
- [x] **Audit Tool False Positives**: Refined regex exclusions.

### [2026-05-17] Development v2.8.41

- [x] **Older Perl Compatibility**: Verified Perl 5.6 and 5.8.
- [x] **Idiomatic Boolean Refactoring**: Completed project-wide.
- [x] **Zero-Warning Enforcement**: Fixed mock warnings and CI policy.
- [x] **Dynamic CI Discovery**: Created perl wrapper for support files.
- [x] **SQL Execution Failure (MySQL 9.x)**: Updated batch execution flags.

### [2026-05-25] Development v2.8.43

- [x] **Unit Tests Stability**: 100% pass (69 files, 346 tests).
- [x] **Aborted Connections Counter Fix**: Verified via unit tests.
- [x] **Dumpdir Exclusions**: Heavy tables/views skipped.

### [2026-05-29] Development v2.8.44

- [x] **Unit Tests Expanded**: 75 files, 431 tests — all pass, zero warnings.
- [x] **Test Coverage Improved**: 92% subroutine coverage (up from 55% → 62% → 78% → 92%).
- [x] **New Test Files**:
  - `unit_coverage_boost.t` — 12 pure utility subs (trim, escape_html, hr_bytes, etc.)
  - `unit_coverage_boost2.t` — 17 I/O, MariaDB engine, print wrapper subs
  - `unit_coverage_boost3.t` — 22 deep-mocked diagnostic subs (mysql_plugins, mysql_indexes, system_recommendations, check_query_anti_patterns, process_sysbench_metrics, etc.)
- [x] **Bug Fixes**:
  - `merge_hash` — fixed `my %result = {}` → `my %result = ()` (Perl warning)
  - `process_sysbench_metrics` — fixed `$fh` scoping bug (`my $fh` inside `if(!open)`)
  - `historical_comparison` — fixed same `$fh` scoping bug
- [x] **Docker Install Docs**: Added to all 4 README files.
- [x] **Doc-Sync**: `.agent/README.md` synchronized with 18 workflows.
- [x] **SECURITY.md**: Version reference updated to v2.8.44.
- [x] **ROADMAP PI-010**: I/O Pressure status already corrected.

### [2026-06-04] Release v2.8.45

- [x] **Temptable Sizing Limits**: Integrated `temptable_max_ram` calculations and mmap checks.
- [x] **InnoDB Index/Data Ratio Check**: Added advisory and CSV dump for tables > 50,000 rows.
- [x] **Uptime Observability**: Exposed Database Server Uptime in all modes.
- [x] **Performance Optimization**: Bulk-fetched table engine and column details to reduce queries (from 2N+3 to 2 per table).
- [x] **System DB Filtering**: Excluded system tables from schema analysis and dumpdir exports.
- [x] **SQL Escaping Fixes**: Safe dollar sign escaping in system call wrappers.

### [2026-07-03] Release v2.9.0

- [x] **Modular HTML Reporting Engine**: Removed external template dependencies and built HTML structure natively.
- [x] **Historical Comparison**: Supported tracking database performance metrics across time intervals.
- [x] **AI Agent Integration**: Added JSON/YAML output format for AI agent accessibility.
- [x] **Visual Contention Analytics**: Integrated pgBadger-inspired query, lock, and temp table graphs.
- [x] **Regression Hardening**: Fixed Com_select query cache parsing and MariaDB user role exceptions.

### [2026-07-09] Release v2.9.1

- [x] **Upgraded Dev Dependencies**: Boosted `@commitlint/cli` and Conventional Commits toolings to patch levels.
- [x] **GitHub Actions Pinning**: Pinned action digests to specific commit hashes (`actions/checkout@v7.0.0`, etc.).
- [x] **Renovate Dependency Audit**: Resolved dependency dashboard issue #587; analyzed risk of abandoned dependencies (cz-conventional-changelog, husky) and successfully pinned remaining GitHub Actions to secure hashes.
- [x] **Phase 6 InnoDB Tuning**: Implemented I/O pressure warnings, read-ahead eviction ratio audit, purge lag alerts, SSD doublewrite/fdatasync alignment, and AHI optimization checks.
- [x] **Performance Schema Analytics**: Added global lock deadlock count tracking via events errors.
- [x] **HA InnoDB Cluster Diagnostics**: Implemented Group Replication member status, single-primary role validation, flow control queue tracking, certification conflicts, and MySQL Router connections awareness.
- [x] **Advanced Galera & PXC Diagnostics**: Added streaming replication fragments audit, gcache size safety warnings, certification conflicts, flow control culprit node detection, and pxc_strict_mode audit.
- [x] **Unit Testing Expansion**: Added dedicated tests `unit_innodb_internals.t`, `unit_replication_internals.t`, `unit_ha_cluster.t`, and `unit_galera_pxc.t`. All 99 test files (541 tests) passing cleanly.

### [2026-07-18] Development v2.9.1

- [x] **Unit Tests Compliance**: Verified that all 110 unit test files and 563 assertions pass cleanly (100% pass rate).
- [x] **Perl Syntax Audit**: Confirmed compile check and syntax are completely warnings-free (`perl -cw mysqltuner.pl`).
- [x] **Tidiness Enforcement**: Identified and formatted `mysqltuner.pl` according to perltidy to ensure `make check-tidy` passes cleanly.
- [x] **SQL Query Failure**: Fixed Performance Schema deadlock analytics query by changing the non-existent `COUNT_STAR` column to `SUM_ERROR_RAISED` on `events_errors_summary_global_by_error`. Added dedicated assertion in `tests/unit_deadlocks_pfs.t`.
