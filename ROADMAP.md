# MySQLTuner-perl Roadmap

This document outlines the strategic direction and future development plans for MySQLTuner-perl. Our mission is to provide the most stable, portable, and reliable performance tuning advisor for MySQL-compatible databases.

## 👤 Governance

To ensure consistency and high-density development, the following roles are defined for roadmap orchestration:

* **Owner**: [Jean-Marie Renouard](https://github.com/jmrenouard) (@jmrenouard) - Ultimate authority on the project, constitution, and core mission.
* **Release Manager**: **Antigravity (AI Agent)** - Responsible for technical validation, testing orchestration, and unified release cycle execution.
* **Product Manager**: **Antigravity (AI Agent)** - Responsible for backlog management, specification design, and execution tracking of the roadmap items.

## 🌟 Strategic Pillars

1. **Production Stability & Safety**: All recommendations must be verified and safe for production.
2. **SQL Modeling & Schema Design**: Beyond operational tuning, provide deep insights into database architecture.
3. **Zero-Dependency Portability**: Maintain single-file architecture with core-only dependencies.
4. **Modern Ecosystem Support**: Seamless integration with Containers (Docker/K8s) and Cloud providers.

---

## 🚀 Development Phases

### Phase 1: Stabilization & Observability (v2.8.31 - v2.8.33) [COMPLETED]

* [x] **[Metadata-Driven CLI Options](file:///documentation/specifications/cli_metadata_refactor.md)**: Refactored option parsing to centralize defaults, validation, and documentation.
* [x] **Enhanced SQL Modeling**: Expanded diagnostic checks for Foreign Key type mismatches, missing indexes, and schema sanitization.
* [x] **[Structured Error Log Ingestion](file:///documentation/specifications/error_log_pfs.md)**: Supported `performance_schema.error_log` for diagnostic ingestion (MySQL 8.0+).
* [x] **Refined Reporting**: Improved data richness in the "Modeling Analysis" tab.

### Phase 2: Advanced Diagnostics (v2.8.34 - v2.8.38) [COMPLETED]

| Item | Status |
| :--- | :--- |
| **System Call Optimization** | [x] Replaced `awk`, `grep`, `hostname`, `uname`, `sysctl` with native Perl. |
| **Native /proc Parsing** | [x] Implemented native parsing for `cpuinfo`, `meminfo`, `swappiness`. |
| **[Index Audit 2.0](file:///documentation/specifications/index_checks_pfs.md)** | [x] Integrated `performance_schema` for redundant/unused index detection. |
| **Observability Log Ingestion** | [x] Support for `syslog`, `journald`, and `performance_schema.error_log`. |
| **Transactional Contention** | [x] Detect isolation levels and long-running transactions. |
| **Buffer Pool Advisory** | [x] More granular analysis of InnoDB Redo Log Capacity based on RAM/Writes. |

### Phase 3: Automation & Ecosystem [COMPLETED]

* [x] **Infrastructure-Aware Tuning**: Detect storage types (NVMe/SSD) and hardware architectures (ARM64/Graviton).
* [x] **[MySQL 9.x Full Compatibility](file:///documentation/specifications/mysql_9_x_support.md)**: Support for removed variables and `mysql_native_password` elimination.
* [x] **[Authentication Plugin Auditing](file:///documentation/specifications/auth_plugin_security_checks.md)**: Detect insecure plugins (SHA-1 based `mysql_native_password`) and recommend migration paths (`caching_sha2_password`, `ed25519`).
* [x] **Sysbench Metrics Integration**: Automated baseline capture and performance comparison within the report.
* [x] **Multi-Cloud Autodiscovery**: Automated detection of RDS, GCP, and Azure specific performance flags and optimizations.
* [x] **Query Anti-Pattern Detection**: Use `performance_schema` to identify non-SARGable queries and `SELECT *` abuse.

### [Phase 4: Advanced Intelligence & Ecosystem](file:///documentation/specifications/roadmap_phase_iv_intelligence.md) [COMPLETED]

* [x] **Smart Migration LTS Advisor**:
  * [x] Automated pre-upgrade risk reports (variable removal, deprecation notices).
  * [x] Compatibility audit for SQL modes, character sets, and version-specific engine changes.
* [x] **Weighted Health Score**:
  * [x] Unified KPI (0-100) aggregating findings from Security, Performance, and Resilience.
  * [x] Comparative scoring against previous runs or established industry baselines.
* [x] **Predictive Capacity Planning**:
  * [x] Data growth forecasting based on binlog throughput and table statistics.
  * [x] Memory headroom analysis for traffic peak forecasting.
  * [x] AUTO_INCREMENT capacity near max value detection.
* [x] **Cluster & Replication Intelligence**:
  * [x] Root cause analysis for replication lag (IO/SQL thread contention).
  * [x] GTID consistency checks and multi-source replication tuning.
* [x] **Consolidated SQL Modeling & Naming Conventions**:
  * [x] Consolidated Primary Key naming, surrogate keys, table singular naming, and table/column casing checks into single-line counters in General recommendations.
  * [x] Implemented advanced dominant style detection and deviations audit for tables, views, indexes, and columns.
* [x] **CSV Export Enhancements**:
  * [x] Export naming convention deviations (tables, views, indexes, columns), primary key naming/surrogate key issues, missing foreign keys, JSON columns without virtual columns, and insecure authentication plugins to separate CSV files.
* [x] **Security Hardening 2.0**:
  * [x] Version-based CVE exposure detection (community-fed database).
  * [x] Advanced encryption-at-rest (TDE) and SSL/TLS cipher suite validation.
  * [x] **Extended Authentication Plugins Audit**: Verify password hashing methods against the extended plugins support matrix (including `mysql_native_password`, `mysql_old_password`, `sha256_password`, `caching_sha2_password`, `unix_socket`, `ed25519`, and the new MariaDB `parsec` plugin). See [AUTHENTICATION_PLUGINS.md](file:///documentation/AUTHENTICATION_PLUGINS.md).
* [x] **Guided Auto-Fix Engine**:
  * [x] Interactive mode to simulate configuration changes.
  * [x] Generation of ready-to-use `SET GLOBAL` or `my.cnf` snippets.
* [x] **Modular Reporting Engine**: Re-implemented native HTML report generation (--reportfile) using built-in layout, removing external template engine dependencies.
* [x] **Complete HTML Report Finalization**: Finalize a complete HTML report file beginning in v2.8.45.
* [x] **Historical Trend & Comparison Analysis**: Support historical comparison of database diagnostics and performance metrics over time.
* [x] **Agent-Ready Output**: Create an agent-ready output format (JSON/YAML) so that MySQLTuner can be easily integrated and used by AI agents.

---

### Phase 5: Code Quality & Regression Hardening [COMPLETED]

> Derived from the test campaign analysis on v2.8.43. Addresses critical code quality issues identified during the 5-iteration test audit.

* [x] **Perl Warning Elimination**:
  * [x] Add definedness guards to `mysql_version_ge()`, `mysql_version_le()`, `mysql_version_eq()` to prevent 74 uninitialized value warnings.
  * [x] Guard `$mycalc{'innodb_log_size_pct'}` and `$myvar{'innodb_log_file_size'}` before use in InnoDB analysis.
  * [x] Guard `$myvar{'version_comment'}` in MariaDB detection path.
* [x] **Version Validation Updates**:
  * [x] Add MySQL 9.6 to `validate_mysql_version()` supported LTS list.
  * [x] Remove MySQL 9.5 (now Outdated) from the LTS list.
* [x] **Test Coverage Expansion**:
  * [x] Achieve ≥80% subroutine test coverage (reached ~92%, only 13 of 167 system/IO-heavy subroutines uncovered).
  * [x] Priority coverage: `check_architecture`, `system_recommendations`, `mysql_indexes`, `mysql_views`, `mysql_routines`, `mysql_triggers`, `make_recommendations`.
  * [x] Add tests for `dump_result` and `close_outputfile` (`get_template_model` obsoleted and removed).
* [x] **Version Comparison Optimization**:
  * [x] Cache parsed version components instead of re-parsing `$myvar{'version'}` on every call to `mysql_version_ge/le/eq`.

---

### [Phase 6: Deep Engine Tuning & Safeguarding](file:///documentation/specifications/roadmap_phase_v_innodb.md) [NOT STARTED]

> Previously Phase 5. Renumbered for logical sequencing after inserting Code Quality phase.

* [ ] **InnoDB Internals 3.0**:
  * [ ] **I/O Pressure & Flushing Advisor**: Combined analysis of `innodb_io_capacity`, `Innodb_buffer_pool_wait_free`, and adaptive flushing metrics to prevent I/O stalls. *(Basic SSD check exists, full advisory missing)*
  * [ ] **Read-Ahead Efficiency Audit**: Measure `Innodb_buffer_pool_read_ahead_evicted` vs `Innodb_buffer_pool_read_ahead` to optimize `innodb_read_ahead_threshold`.
  * [ ] **Deadlock & Contention Analytics**: Historic deadlock tracking via `performance_schema` with specific table-level contention reports.
  * [ ] **Modern Storage Alignment**: Deep audit of `innodb_doublewrite_pages` alignment (128 for MySQL 8.4+), `innodb_use_fdatasync` for syscall reduction, and `innodb_flush_method`.
* [ ] **Resource Isolation & Multi-Tenancy**:
  * [ ] **NUMA-Aware Memory Allocation**: Verification of `innodb_numa_interleave` and system memory controller balance.
  * [ ] **Temp & Undo Lifecycle Manager**: Proactive advisory for MariaDB temporary tablespace online truncation (`innodb_truncate_temporary_tablespace_now`) and MySQL undo health.
* [ ] **Adaptive Intelligence**:
  * [ ] **Read-Ahead & Change Buffer Optimization**: Dynamic recommendation to disable legacy features (`innodb_change_buffering`, `innodb_adaptive_hash_index`) based on workload patterns.
  * [ ] **Purge Lag Prevention**: Automated detected of purge lag (`Innodb_history_list_length`) and recommendation for `innodb_purge_threads` scaling.

### [Phase 7: High Availability & InnoDB Cluster](file:///documentation/specifications/roadmap_phase_vi_innodb_cluster.md) [NOT STARTED]

> Previously Phase 6. No code implementation exists yet.

* [ ] **Distributed Consistency & Performance**:
  * [ ] **Group Replication Health Audit**: Detailed analysis of `MEMBER_STATE`, `MEMBER_ROLE`, and `MEMBER_VERSION` via `performance_schema.replication_group_members`.
  * [ ] **Advanced Flow Control Tuning**: Precise monitoring of Certification (`COUNT_TRANSACTIONS_IN_QUEUE`) and Applier (`COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE`) queues.
  * [ ] **Certification Conflict Analytics**: Quantitative detection of transaction local rollbacks (> 5% threshold) for Multi-Primary conflict troubleshooting.
* [ ] **Cluster Resilience & Topology Optimization**:
  * [ ] **Inter-Node Latency Impact**: Analysis of how network performance affects the group consensus and triggers write throttling.
  * [ ] **Communication Message Cache**: Verification of `group_replication_message_cache_size` against system RAM to prevent OOM during network partitions.
  * [ ] **Auto-Recovery Channel Tuning**: Optimization of incremental state transfers (IST) vs SST during member re-joining.
* [ ] **HA Ecosystem & Proxy Support**:
  * [ ] **MySQL Router Awareness**: (Experimental) Detection of Router-mediated connections via `performance_schema.threads` metadata.
  * [ ] **Quorum Integrity Framework**: Alignment check for `unreachable_majority_timeout` and partition handling configurations.
  * [ ] **MTR (Multi-Threaded Replication) Scaling**: Dynamic advisory for `slave_parallel_workers` based on cluster apply lag.

### [Phase 8: Modern Replication & GTID Mastery](file:///documentation/specifications/roadmap_phase_vii_replication.md) [PARTIAL]

> Previously Phase 7. Basic GTID checks exist (7 references). Parallel/compression/semi-sync are missing.

* [/] **Data Consistency & GTID Integrity**:
  * [/] **GTID Gap Analysis**: Detection of non-contiguous global transaction identifiers and missing transactions across the replication chain. *(Basic GTID mode checks exist)*
  * [ ] **Consistency Enforcement Audit**: Verification of `enforce_gtid_consistency`, `gtid_mode=ON`, and `binlog_format=ROW` for all nodes.
* [ ] **Throughput & Parallelism Optimization**:
  * [ ] **Parallel Applier (MTR) Tuning**: Advanced monitoring of worker thread saturation and busy-wait distribution.
  * [ ] **Dependency Tracking Analysis**: Verification of dependency tracking type (`COMMIT_ORDER` vs `WRITESET` in MySQL) and `slave_parallel_mode` (MariaDB).
* [ ] **Network & Durability Enhancements**:
  * [ ] **Binary Log Compression Audit**: Monitoring efficiency and CPU impact of `binlog_transaction_compression` (MySQL 8.0.20+).
  * [ ] **Binlog Cache Deep-Dive**: Analysis of `Binlog_cache_disk_use` ratio to detect large transactions causing disk stalls.
  * [ ] **Semi-Sync Safety Check**: Dynamic analysis of semi-synchronous wait points (`AFTER_SYNC` vs `AFTER_COMMIT`) and fallback triggers.
  * [ ] **Multi-Source Channel Monitoring**: Full observability for multi-master and multi-channel replication topologies.

### [Phase 9: Advanced Galera Cluster 4 & PXC 8.0](file:///documentation/specifications/roadmap_phase_viii_galera.md) [PARTIAL]

> Previously Phase 8. Foundation exists (106 wsrep + 51 galera references). Advanced diagnostics missing.

* [ ] **Synchronous Efficiency & Streaming**:
  * [ ] **Streaming Replication Audit**: Observability for large transaction fragments (`wsrep_streaming_log_writes`) and their I/O footprint (MariaDB 10.4+).
  * [ ] **Gcache Lifecycle Optimization**: Advanced sizing advisory for `gcache.size` vs write load to maximize IST success.
* [ ] **Conflict & Performance Diagnostics**:
  * [ ] **Certification Failure Deep-Dive**: Quantitative analysis of brute-force aborts (`wsrep_local_bf_aborts`) and certification conflicts.
  * [ ] **Cluster-Wide Flow Control Mapping**: Identification of "bottleneck nodes" (Victim vs Culprit) using `wsrep_flow_control_sent` metrics.
  * [ ] **Write-Set Dependency Analysis**: Optimization of `wsrep_slave_threads` based on `wsrep_cert_deps_distance` tracking.
* [ ] **Stability & Scalability Safeguards**:
  * [ ] **Network Jitter Detection**: Monitoring of group communication latency (`wsrep_evs_repl_latency` statistics) and its impact on consistency.
  * [ ] **PXC Strict Mode Verification**: Consistency checks for Percona XtraDB Cluster specific security and performance enforcements.

### [Phase 10: Data Integrity & Checksum Verification](file:///documentation/specifications/roadmap_phase_ix_integrity.md) [PARTIAL]

> Previously Phase 9. Basic checksum algorithm checks exist (5 refs each). Binlog/doublewrite missing.

* [/] **Storage Engine Protection**:
  * [/] **InnoDB Page Integrity Audit**: Verification of `innodb_checksum_algorithm` strength (`full_crc32` for MariaDB 10.5+, `CRC32` for MySQL) and ensuring `innodb_checksums` is active. *(Basic implementation exists)*
  * [ ] **Redo Log Safety Check**: Monitoring of `innodb_log_checksums` to prevent undetected recovery from corrupted logs.
  * [ ] **Doublewrite Consistency**: Alignment check between doublewrite buffer activity and storage atomic write capabilities.
* [ ] **Replication Pipeline Validation**:
  * [ ] **Binlog Event Integrity**: Verification of `binlog_checksum` (CRC32) across the topology and alignment with storage algorithms.
  * [ ] **End-to-End Verification Audit**: Analysis of `source_verify_checksum` and `replica_sql_verify_checksum` settings.
  * [ ] **Relay Log Hardening**: Verification of checksum validation before transaction application on replicas.

### Phase 11: Workload Analysis & Traffic Profiling [NOT STARTED]

> Previously Phase 10.

* [ ] **Query Performance Profiling**:
  * [ ] **Wait Event Fingerprinting**: Aggregation of `performance_schema` wait events to identify the primary database bottleneck (CPU, disk, lock, network).
  * [ ] **Workload Characterization**: Automated classification of the database as Read-Heavy, Write-Heavy, or Mixed based on I/O ratios.
* [ ] **Metadata & Object Lifecycle**:
  * [ ] **Table Churn & Fragmentation Advisor**: Identification of tables with frequent DML that require periodic `OPTIMIZE TABLE`.
  * [ ] **Auto-Increment Exhaustion Audit**: Monitoring of large tables for potential auto-increment overflow (especially 32-bit integers).

### [Phase 12: Advanced Log Parser & Lock Monitoring](file:///documentation/specifications/roadmap_phase_xi_log_parser.md) [NOT STARTED]

> Previously Phase 11.

* [ ] **Logging & Lock Instrumentation**:
  * [ ] **Deadlock Logging Audit**: Verification of `innodb_print_all_deadlocks` and `innodb_status_output` settings.
  * [ ] **Lock Monitor Insights**: Advisory for enabling `innodb_status_output_locks` during active contention troubleshooting.
  * [ ] **Log Hygiene & Rotation**: Verification of log rotation policies and verbosity settings (`log_error_verbosity` / `log_findings`).
* [ ] **Proactive Error Log Tracer**:
  * [ ] **Semantic Error Detection**: Automated parsing for OOM (Out of Memory) patterns, semaphore waits, and filesystem bottlenecks.
  * [ ] **Corruption & Recovery Guard**: Early detection of "crashed" tables or InnoDB checksum failures in the logs.
  * [ ] **Resource Limit Correlation**: Mapping of "too many open files" errors to `open_files_limit` and OS-level table cache settings.
* [ ] **Correlation Engine (Experimental)**:
  * [ ] **Temporal Event Linking**: Logic to link error log timestamps with Performance Schema wait events or high CPU load detected during execution.

### [Phase 13: Sectional Global Indicators & KPIs](file:///documentation/specifications/roadmap_phase_xii_sectional_indicators.md) [COMPLETED]

> Previously Phase 12.

* [x] **Unified Health Dashboard**:
  * [x] **Sectional Health Scoring**: Implementation of a 0-100 KPI for each major diagnostic area (Storage Engine, Security, Replication, SQL Modeling).
  * [x] **Critical Findings Executive Summary**: Automated prioritization of the top 3 items per section with color-coded badges (🔴 Critical, 🟡 Finding, 🟢 Optimal).
* [x] **Efficiency & Resource Mapping**:
  * [x] **Throughput Efficiency Index**: Real-time ratio analysis of logical work (Queries/sec) vs physical resource consumption (`Innodb_buffer_pool_read_requests`).
  * [x] **Resource Saturation Heatmap**: Visual representation of proximity to system limits (CPU/MEM/IO/Connections).
* [x] **Comparative Insights**:
  * [x] **Historical Performance Deltas**: Sectional trend analysis identifying areas of performance regression or improvement based on previous run data.

### [Phase 14: Export Optimization & Dumpdir Hardening](file:///documentation/specifications/roadmap_phase_xiii_export_optimization.md) [COMPLETED]

> Previously Phase 13.

* [x] **Export Performance Safeguards**:
  * [x] **Default Row Limit**: Implementation of a 50,000 rows default limit for all `dumpdir` exports to prevent database slowdowns.
  * [x] **Configurable Quotas**: Addition of `--dump-limit` option to allow user-defined row overrides.
* [x] **Metadata & Durability**:
  * [x] **Manifest Generation**: Automated generation of `manifest.json`/`metadata.txt` for better traceability of offline diagnostic snapshots.
  * [x] **I/O Latency Monitoring**: Real-time tracking of export duration per object with notices for slow disk subsystems.
* [x] **Compression & Efficiency**:
  * [x] **On-the-fly Compression**: Support for compressed `.gz` exports to minimize disk footprint in container/limited-storage environments.

## 🔮 Strategic Technical Evolutions

* [ ] Set up a pipeline to automatically audit and verify reference link availability inside the repository documentation to prevent dead links.
* [ ] Integrate standard documentation reference anchors dynamically within MySQLTuner CLI help screens and specific advisor output blocks.
* [ ] Support localized versions of the reference documentation matching other translations of the script (e.g. Italian, French, Russian).
* [ ] **Automated Changelog Formatting Verification**: Implement a Git pre-commit hook that automatically checks if the `Changelog` has been modified when changes of type `feat` or `fix` are detected, preventing commits without changelog documentation.
* [ ] **Containerized Validation Runners**: Standardize local pre-flight checks by executing all verification steps (including unit tests and version consistency checks) inside a standardized, minimal Docker environment to avoid environmental differences between developer environments and CI.
* [ ] **Interactive Release Orchestrator**: Create a script that automates the interactive selection of version bump categories (micro, minor, major), executes the version replacement across all 6 reference locations, and automatically runs the `release_gen.py` script to generate release notes in a single workflow step.
* [ ] **Automated Release Notes Synchronization**: Create a script or Git hook that automatically extracts changes from the branch commits and populates the `Executive Summary` sections in both the `Changelog` and release notes to prevent manual synchronization omissions.
* [ ] **Schema Validation for Release Artifacts**: Implement a CI step to parse and validate that markdown formats, issues referenced, and version definitions in the `releases/` directory are syntactically and logically correct before release tagging.
* [ ] **Structured Roadmap Schema Validation**: Implement a markdown linter or schema validator specifically for the `ROADMAP.md` checklist syntax (verifying correct hyperlinks, file pathways, and category labels).
* [ ] **Automated Status Checklist Sync**: Integrate a workflow script that automatically marks roadmap checklist items as completed (`[x]`) upon detection of related commit scopes (e.g. `feat(auth):` marking authentication items as done).

## 🤝 Contribution & Feedback

We welcome community feedback on this roadmap. If you have specific feature requests or want to contribute to a specific phase, please open an issue on our [GitHub repository](https://github.com/jmrenouard/MySQLTuner-perl).
