# POTENTIAL ISSUES AUDIT

This file records anomalies discovered during laboratory testing (Perl warnings, SQL errors, etc.).

## [2026-05-26 Audit] Massive Audit Campaign v2.8.43

### Unit Test Results

- **Status**: ✅ ALL PASS
- **Files**: 69 test files
- **Assertions**: 346 tests
- **Perl Syntax**: Clean (`perl -cw mysqltuner.pl` — no warnings)

### Test Coverage Analysis

| Metric | Value |
|:---|:---|
| Total Subroutines | 165 |
| Tested Subroutines | ~91 (~55%) |
| Untested Subroutines | ~74 (~45%) |

#### Key Untested Subroutines (High Priority)

- `check_architecture`, `system_recommendations`, `mysql_indexes`
- `mysql_views`, `mysql_routines`, `mysql_triggers`
- `make_recommendations`, `close_outputfile`, `dump_result`
- `cloud_setup`, `get_ssh_prefix`, `get_container_prefix`
- `build_mysql_connection_command`, `select_csv_file`
- `write_manifest_files`, `get_tuning_info`

### 🔴 Critical Issues

#### PI-001: MySQL 8.0 EOL Status Incorrect
- **Source**: [mysql_support.md](file:///mysql_support.md)
- **Impact**: MySQL 8.0 reached EOL on 2026-04-30 but was listed as "Supported"
- **Status**: [x] **FIXED** — Updated to "Outdated"

#### PI-002: SECURITY.md Stale Version Reference
- **Source**: [SECURITY.md](file:///SECURITY.md) line 11
- **Impact**: Referenced v2.8.38 instead of current v2.8.43
- **Status**: [x] **FIXED** — Updated to v2.8.43

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
- **Status**: [x] **FIXED** — Updated to ~400

### 🟡 Medium Issues

#### PI-006: 74 out of 165 subroutines have zero test coverage
- **Impact**: Functions like `check_architecture`, `system_recommendations`, `mysql_indexes`, `mysql_views`, `mysql_routines`, `mysql_triggers`, `make_recommendations`, `close_outputfile`, `dump_result` have no unit tests
- **Severity**: 🟡 MEDIUM — regression risk on core diagnostic functions
- **Coverage rate**: ~55% of subroutines referenced in at least one test

#### PI-007: Extremely large subroutines
- **Impact**: Several functions exceed 500+ lines, making maintenance difficult
- **Functions to analyze**: `mysql_pfs` (1520 lines), `mysql_stats` (707), `mysql_innodb` (678), `execute_system_command` (565), `calculations` (492)
- **Severity**: 🟡 MEDIUM — SOLID SRP violation, but constrained by single-file architecture

#### PI-008: `mysql_version_ge/le/eq` parse version on every call
- **Source**: Each call to `mysql_version_ge()`, `mysql_version_le()`, `mysql_version_eq()` re-parses `$myvar{'version'}` via regex
- **Impact**: Redundant computation — called 100+ times across the script
- **Severity**: 🟢 LOW — performance impact minimal but code duplication

#### PI-009: MariaDB 10.6 Approaching EOL
- **Source**: [mariadb_support.md](file:///mariadb_support.md)
- **Impact**: MariaDB 10.6 LTS EOL is 2026-07-06 (41 days away)
- **Severity**: 🟡 MEDIUM — plan deprecation proactively

#### PI-010: ROADMAP Phase 5 Status Incorrect
- **Source**: [ROADMAP.md](file:///ROADMAP.md) line 84
- **Impact**: I/O Pressure & Flushing Advisor marked `[/]` but only basic `innodb_io_capacity` references exist — no flushing advisor implemented
- **Status**: [ ] Needs correction to `[ ]`

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

#### PI-016: ROADMAP Phases 10-12 — Not started
- Workload Analysis & Traffic Profiling: Not implemented
- Advanced Log Parser & Lock Monitoring: Not implemented
- Sectional Global Indicators: Not implemented

#### PI-017: ROADMAP Phase 13 (Export Optimization) — COMPLETED ✅

---

## [2026-05-26 Audit] Security Posture Assessment

### Overall Posture: ✅ GOOD

| Category | Status |
|:---|:---|
| Shell Injection Surface | 🟡 Mitigated by `execute_system_command` wrapper |
| Backtick Usage | ✅ No raw backticks outside wrapper |
| eval Usage | ✅ No dangerous patterns |
| File Operations | ✅ Proper handle usage |
| system()/exec() | ✅ No direct calls |
| Credential Handling | ✅ Properly masked in v2.8.43 |
| Temp File Safety | ✅ Symlink protection + atomic writes |
| SQL Injection | ✅ No user-controlled SQL interpolation |

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
