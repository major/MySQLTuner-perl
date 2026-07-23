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

| Item                                                                            | Status                                                                      |
| :--------------------------------------------------------------------------------| :----------------------------------------------------------------------------|
| **System Call Optimization**                                                    | [x] Replaced `awk`, `grep`, `hostname`, `uname`, `sysctl` with native Perl. |
| **Native /proc Parsing**                                                        | [x] Implemented native parsing for `cpuinfo`, `meminfo`, `swappiness`.      |
| **[Index Audit 2.0](file:///documentation/specifications/index_checks_pfs.md)** | [x] Integrated `performance_schema` for redundant/unused index detection.   |
| **Observability Log Ingestion**                                                 | [x] Support for `syslog`, `journald`, and `performance_schema.error_log`.   |
| **Transactional Contention**                                                    | [x] Detect isolation levels and long-running transactions.                  |
| **Buffer Pool Advisory**                                                        | [x] More granular analysis of InnoDB Redo Log Capacity based on RAM/Writes. |

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

### [Phase 6: Deep Engine Tuning & Safeguarding](file:///documentation/specifications/roadmap_phase_v_innodb.md) [COMPLETED]

> Previously Phase 5. Renumbered for logical sequencing after inserting Code Quality phase.

* [x] **InnoDB Internals 3.0**:
  * [x] **I/O Pressure & Flushing Advisor**: Combined analysis of `innodb_io_capacity`, `Innodb_buffer_pool_wait_free`, and adaptive flushing metrics to prevent I/O stalls. *(Basic SSD check exists, full advisory missing)*
  * [x] **Read-Ahead Efficiency Audit**: Measure `Innodb_buffer_pool_read_ahead_evicted` vs `Innodb_buffer_pool_read_ahead` to optimize `innodb_read_ahead_threshold`.
  * [x] **Deadlock & Contention Analytics**: Historic deadlock tracking via `performance_schema` with specific table-level contention reports.
  * [x] **Modern Storage Alignment**: Deep audit of `innodb_doublewrite_pages` alignment (128 for MySQL 8.4+), `innodb_use_fdatasync` for syscall reduction, and `innodb_flush_method`.
* [x] **Resource Isolation & Multi-Tenancy**:
  * [x] **NUMA-Aware Memory Allocation**: Verification of `innodb_numa_interleave` and system memory controller balance.
  * [x] **Temp & Undo Lifecycle Manager**: Proactive advisory for MariaDB temporary tablespace online truncation (`innodb_truncate_temporary_tablespace_now`) and MySQL undo health.
* [x] **Adaptive Intelligence**:
  * [x] **Read-Ahead & Change Buffer Optimization**: Dynamic recommendation to disable legacy features (`innodb_change_buffering`, `innodb_adaptive_hash_index`) based on workload patterns.
  * [x] **Purge Lag Prevention**: Automated detected of purge lag (`Innodb_history_list_length`) and recommendation for `innodb_purge_threads` scaling.

### [Phase 7: High Availability & InnoDB Cluster](file:///documentation/specifications/roadmap_phase_vi_innodb_cluster.md) [COMPLETED]

> Previously Phase 6. No code implementation exists yet.

* [x] **Distributed Consistency & Performance**:
  * [x] **Group Replication Health Audit**: Detailed analysis of `MEMBER_STATE`, `MEMBER_ROLE`, and `MEMBER_VERSION` via `performance_schema.replication_group_members`.
  * [x] **Advanced Flow Control Tuning**: Precise monitoring of Certification (`COUNT_TRANSACTIONS_IN_QUEUE`) and Applier (`COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE`) queues.
  * [x] **Certification Conflict Analytics**: Quantitative detection of transaction local rollbacks (> 5% threshold) for Multi-Primary conflict troubleshooting.
* [x] **Cluster Resilience & Topology Optimization**:
  * [x] **Inter-Node Latency Impact**: Analysis of how network performance affects the group consensus and triggers write throttling.
  * [x] **Communication Message Cache**: Verification of `group_replication_message_cache_size` against system RAM to prevent OOM during network partitions.
  * [x] **Auto-Recovery Channel Tuning**: Optimization of incremental state transfers (IST) vs SST during member re-joining.
* [x] **HA Ecosystem & Proxy Support**:
  * [x] **MySQL Router Awareness**: (Experimental) Detection of Router-mediated connections via `performance_schema.threads` metadata.
  * [x] **Quorum Integrity Framework**: Alignment check for `unreachable_majority_timeout` and partition handling configurations.
  * [x] **MTR (Multi-Threaded Replication) Scaling**: Dynamic advisory for `slave_parallel_workers` based on cluster apply lag.

### [Phase 8: Modern Replication & GTID Mastery](file:///documentation/specifications/roadmap_phase_vii_replication.md) [COMPLETED]

> Previously Phase 7. Basic GTID checks exist (7 references). Parallel/compression/semi-sync are missing.

* [x] **Data Consistency & GTID Integrity**:
  * [x] **GTID Gap Analysis**: Detection of non-contiguous global transaction identifiers and missing transactions across the replication chain. *(Basic GTID mode checks exist)*
  * [x] **Consistency Enforcement Audit**: Verification of `enforce_gtid_consistency`, `gtid_mode=ON`, and `binlog_format=ROW` for all nodes.
* [x] **Throughput & Parallelism Optimization**:
  * [x] **Parallel Applier (MTR) Tuning**: Advanced monitoring of worker thread saturation and busy-wait distribution.
  * [x] **Dependency Tracking Analysis**: Verification of dependency tracking type (`COMMIT_ORDER` vs `WRITESET` in MySQL) and `slave_parallel_mode` (MariaDB).
* [x] **Network & Durability Enhancements**:
  * [x] **Binary Log Compression Audit**: Monitoring efficiency and CPU impact of `binlog_transaction_compression` (MySQL 8.0.20+).
  * [x] **Binlog Cache Deep-Dive**: Analysis of `Binlog_cache_disk_use` ratio to detect large transactions causing disk stalls.
  * [x] **Semi-Sync Safety Check**: Dynamic analysis of semi-synchronous wait points (`AFTER_SYNC` vs `AFTER_COMMIT`) and fallback triggers.
  * [x] **Multi-Source Channel Monitoring**: Full observability for multi-master and multi-channel replication topologies.

### [Phase 9: Advanced Galera Cluster 4 & PXC 8.0](file:///documentation/specifications/roadmap_phase_viii_galera.md) [COMPLETED]

> Previously Phase 8. Foundation exists (106 wsrep + 51 galera references). Advanced diagnostics missing.

* [x] **Synchronous Efficiency & Streaming**:
  * [x] **Streaming Replication Audit**: Observability for large transaction fragments (`wsrep_streaming_log_writes`) and their I/O footprint (MariaDB 10.4+).
  * [x] **Gcache Lifecycle Optimization**: Advanced sizing advisory for `gcache.size` vs write load to maximize IST success.
* [x] **Conflict & Performance Diagnostics**:
  * [x] **Certification Failure Deep-Dive**: Quantitative analysis of brute-force aborts (`wsrep_local_bf_aborts`) and certification conflicts.
  * [x] **Cluster-Wide Flow Control Mapping**: Identification of "bottleneck nodes" (Victim vs Culprit) using `wsrep_flow_control_sent` metrics.
  * [x] **Write-Set Dependency Analysis**: Optimization of `wsrep_slave_threads` based on `wsrep_cert_deps_distance` tracking.
* [x] **Stability & Scalability Safeguards**:
  * [x] **Network Jitter Detection**: Monitoring of group communication latency (`wsrep_evs_repl_latency` statistics) and its impact on consistency.
  * [x] **PXC Strict Mode Verification**: Consistency checks for Percona XtraDB Cluster specific security and performance enforcements.

### [Phase 10: Data Integrity & Checksum Verification](file:///documentation/specifications/roadmap_phase_ix_integrity.md) [COMPLETED]

> Previously Phase 9. Basic checksum algorithm checks exist (5 refs each). Binlog/doublewrite missing.

* [x] **Storage Engine Protection**:
  * [x] **InnoDB Page Integrity Audit**: Verification of `innodb_checksum_algorithm` strength (`full_crc32` for MariaDB 10.5+, `CRC32` for MySQL) and ensuring `innodb_checksums` is active. *(Basic implementation exists)*
  * [x] **Redo Log Safety Check**: Monitoring of `innodb_log_checksums` to prevent undetected recovery from corrupted logs.
  * [x] **Doublewrite Consistency**: Alignment check between doublewrite buffer activity and storage atomic write capabilities.
* [x] **Replication Pipeline Validation**:
  * [x] **Binlog Event Integrity**: Verification of `binlog_checksum` (CRC32) across the topology and alignment with storage algorithms.
  * [x] **End-to-End Verification Audit**: Analysis of `source_verify_checksum` and `replica_sql_verify_checksum` settings.
  * [x] **Relay Log Hardening**: Verification of checksum validation before transaction application on replicas.

### Phase 11: Workload Analysis & Traffic Profiling [COMPLETED]

> Previously Phase 10.

* [x] **Query Performance Profiling**:
  * [x] **Wait Event Fingerprinting**: Aggregation of `performance_schema` wait events to identify the primary database bottleneck (CPU, disk, lock, network).
  * [x] **Workload Characterization**: Automated classification of the database as Read-Heavy, Write-Heavy, or Mixed based on I/O ratios.
* [x] **Metadata & Object Lifecycle**:
  * [x] **Table Churn & Fragmentation Advisor**: Identification of tables with frequent DML that require periodic `OPTIMIZE TABLE`.
  * [x] **Auto-Increment Exhaustion Audit**: Monitoring of large tables for potential auto-increment overflow (especially 32-bit integers).

### [Phase 12: Advanced Log Parser & Lock Monitoring](file:///documentation/specifications/roadmap_phase_xi_log_parser.md) [COMPLETED]

> Previously Phase 11.

* [x] **Logging & Lock Instrumentation**:
  * [x] **Deadlock Logging Audit**: Verification of `innodb_print_all_deadlocks` and `innodb_status_output` settings.
  * [x] **Lock Monitor Insights**: Advisory for enabling `innodb_status_output_locks` during active contention troubleshooting.
  * [x] **Log Hygiene & Rotation**: Verification of log rotation policies and verbosity settings (`log_error_verbosity` / `log_findings`).
* [x] **Proactive Error Log Tracer**:
  * [x] **Semantic Error Detection**: Automated parsing for OOM (Out of Memory) patterns, semaphore waits, and filesystem bottlenecks.
  * [x] **Corruption & Recovery Guard**: Early detection of "crashed" tables or InnoDB checksum failures in the logs.
  * [x] **Resource Limit Correlation**: Mapping of "too many open files" errors to `open_files_limit` and OS-level table cache settings.
* [x] **Correlation Engine (Experimental)**:
  * [x] **Temporal Event Linking**: Logic to link error log timestamps with Performance Schema wait events or high CPU load detected during execution.

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

### [Phase 15: Interactive Multi-Page HTML Reports & Detailed Exports](file:///documentation/specifications/roadmap_phase_xiv_html_reports.md) [COMPLETED]

* [x] **Summary Page Dashboard**:
  * [x] Executive summary layout with a modern circular health score gauge, category scores breakdown, and top findings.
* [x] **Topic-Based Metrics Partitioning**:
  * [x] Structure the report into tabs/views: Memory, Connections, Storage Engines, Performance, Security, SQL Modeling, Replication.
* [x] **SVG/CSS-Based Ratios Visualization**:
  * [x] Render interactive bars/gauges for InnoDB buffer pool hit rate, thread cache hit rate, disk temp tables, and connection saturation.
* [x] **Embedded CSV Data Exports**:
  * [x] Embed base64 or raw string CSV representation of variables and findings in JavaScript, enabling instant local CSV downloads.

### [Phase 16: AI Agent Integration & Actionable JSON Schema](file:///documentation/specifications/roadmap_phase_xv_ai_agent_integration.md) [COMPLETED]

* [x] **Structured Actionable JSON Output**:
  * [x] Implementation of `--agent-json` flag returning a standardized schema.
* [x] **Expected Outcomes & Rollback Statements**:
  * [x] Each recommendation includes explicit expected outcome description and corresponding rollback statement.
* [x] **Risk Assessment & Impact Scoring**:
  * [x] Assign deterministic impact score (1-10) and category/risk level to each recommendation.

### [Phase 17: Dockerized Auditing Daemon & MCP Server Support](file:///documentation/specifications/roadmap_phase_xvi_mcp_server.md) [COMPLETED]

* [x] **Interval Auditing Daemon**:
  * [x] Dockerized execution environment running auditing loops every X hours with caching.
* [x] **Model Context Protocol (MCP) Server**:
  * [x] Expose caching layer, latest results, and immediate auditing as MCP tools and resources.
* [x] **Safe execution & Rollbacks**:
  * [x] Implement secure database interaction tools to apply or rollback recommendations.

## 🔮 [Strategic Technical Evolutions](file:///documentation/specifications/strategic_technical_evolutions.md)

### [Phase 18: Documentation Integrity & Dynamic References](file:///documentation/specifications/roadmap_phase_xvii_documentation_integrity.md) [NOT STARTED]

* [ ] **Reference Link Auditing Pipeline**:
  * [ ] Set up a pipeline to automatically audit and verify reference link availability inside the repository documentation to prevent dead links.
* [ ] **Dynamic Help Screen Anchors**:
  * [ ] Integrate standard documentation reference anchors dynamically within MySQLTuner CLI help screens and specific advisor output blocks.
* [ ] **Localization Support**:
  * [ ] Support localized versions of the reference documentation matching other translations of the script (e.g. Italian, French, Russian).

### [Phase 19: CI/CD Quality Gates & Validation Runners](file:///documentation/specifications/roadmap_phase_xviii_ci_quality_gates.md) [NOT STARTED]

* [ ] **Automated Changelog Verification**:
  * [ ] Implement a Git pre-commit hook that automatically checks if the `Changelog` has been modified when changes of type `feat` or `fix` are detected, preventing commits without changelog documentation.
* [ ] **Containerized Validation Runners**:
  * [ ] Standardize local pre-flight checks by executing all verification steps (including unit tests and version consistency checks) inside a standardized, minimal Docker environment to avoid environmental differences between developer environments and CI.
* [ ] **Schema Validation for Release Artifacts**:
  * [ ] Implement a CI step to parse and validate that markdown formats, issues referenced, and version definitions in the `releases/` directory are syntactically and logically correct before release tagging.

### [Phase 20: Release Automation & Synchronization](file:///documentation/specifications/roadmap_phase_xix_release_automation.md) [NOT STARTED]

* [ ] **Interactive Release Orchestrator**:
  * [ ] Create a script that automates the interactive selection of version bump categories (micro, minor, major), executes the version replacement across all 6 reference locations, and automatically runs the `release_gen.py` script to generate release notes in a single workflow step.
* [ ] **Automated Release Notes Synchronization**:
  * [ ] Create a script or Git hook that automatically extracts changes from the branch commits and populates the `Executive Summary` sections in both the `Changelog` and release notes to prevent manual synchronization omissions.

### [Phase 21: Structured Roadmap Automation](file:///documentation/specifications/roadmap_phase_xx_roadmap_automation.md) [NOT STARTED]

* [ ] **Structured Roadmap Schema Validation**:
  * [ ] Implement a markdown linter or schema validator specifically for the `ROADMAP.md` checklist syntax (verifying correct hyperlinks, file pathways, and category labels).
* [ ] **Automated Status Checklist Sync**:
  * [ ] Integrate a workflow script that automatically marks roadmap checklist items as completed (`[x]`) upon detection of related commit scopes (e.g. `feat(auth):` marking authentication items as done).

### [Phase 22: High Availability & Replication Auto-Discovery](file:///documentation/specifications/roadmap_phase_xxi_replication_autodiscovery.md) [NOT STARTED]

* [ ] **Topology Auto-Discovery**:
  * [ ] Query MySQL system tables and variables to automatically identify the topology (Galera Cluster, InnoDB Cluster, or Logical Replication source/replica).
* [ ] **Galera Member Exploration**:
  * [ ] Discover all active cluster members from `wsrep_incoming_addresses` and support launching auditing runs on replica nodes.
* [ ] **Logical Replica Lag Auditing**:
  * [ ] Track source-replica status, check lag metrics, and audit IO/SQL thread parameters on replicas.
* [ ] **InnoDB Cluster Auditing**:
  * [ ] Query `mysql_innodb_cluster_metadata` to retrieve cluster members status and performance schema metrics.

### [Phase 23: E2E Quality and Query Safety Hardening](file:///documentation/specifications/roadmap_phase_xxii_query_safety.md) [IN PROGRESS]

* [x] **Performance Schema Pre-Flight Checks**:
  * [x] Dynamically verify Performance Schema table availability in `information_schema.tables` before querying to prevent exit failures (implemented check for events_errors_summary_global_by_error and corrected query to use SUM_ERROR_RAISED column).
* [ ] **Horizontal Multi-Scenario Comparative HTML Report**:
  * [ ] Extend the HTML dashboard with a side-by-side comparative table showing metric differences between Standard, Container, and Dumpdir modes.
* [ ] **Trace Logging for SQL Compilation Errors**:
  * [ ] Capture and redirect SQL execution errors to a dedicated debug log rather than silent deletion to assist DBAs in diagnosing permission restrictions.

### Phase 24: MySQL Boolean Normalization Engine [NOT STARTED]

* [ ] **System-Wide Boolean Normalization**:
  * [ ] Create an internal utility function to convert and normalize system variable boolean representations (`ON`/`OFF`, `1`/`0`, `YES`/`NO`) to simplify all current and future conditional logic in `mysqltuner.pl`.

### Phase 25: Deprecated System Variables & Synonyms Audit [NOT STARTED]

* [ ] **Obsolete Configuration Warnings**:
  * [ ] Add specific diagnostic warnings when obsolete synonyms (e.g. `log_slow_queries`) are configured instead of the modern recommended variables (e.g. `slow_query_log`).

### Phase 26: Subtest Decomposition & Test Suite Optimization [NOT STARTED]

* [ ] **Granular Unit Test Decomposition**:
  * [ ] Continue decomposing monolithic test scripts in the `tests/` directory into structured, human-assimilable subtests to simplify regression tracking and database laboratory debugging.

### Phase 27: Multi-Language Normalization & Duplicate Elimination [NOT STARTED]

> Addresses the 6 cross-language duplications identified during the transversal project audit (Perl/Python/Bash/YAML).

* [ ] **CVE Update Consolidation (Perl-Only)**:
  * [ ] Merge enriched fields from `updateCVElist.py` (CVSS scores, references, publication dates) into `updateCVElist.pl`.
  * [ ] Deprecate and remove `updateCVElist.py` and its `__pycache__/` directory after migration validation.
* [ ] **Centralized Version Extraction Script**:
  * [ ] Create a single `build/get_version.sh` script encapsulating the version extraction logic (`grep '- Version ' mysqltuner.pl | awk '{ print $NF}'`) currently duplicated in 5 locations (Makefile, 2 workflows, 1 test script).
  * [ ] Refactor Makefile, `publish_release.yml`, `docker_publish.yml`, and `tests/check_release_files.sh` to source this single script.
* [ ] **Orphan File Cleanup**:
  * [ ] Remove empty `JenkinsFile` (0 bytes, no pipeline defined).
  * [ ] Remove `mysqltuner.pl.bak` and `tests/unit_versions.t.bak` (unversioned backup files).

### Phase 28: CI/CD Version Matrix Harmonization [NOT STARTED]

> Resolves critical discrepancies where CI workflows test exclusively EOL database versions while ignoring supported ones.

* [ ] **Centralized CI Version Matrix**:
  * [ ] Create a machine-readable matrix file (`build/ci_matrix.json`) defining supported DB versions for CI, consumed by all GitHub Actions workflows via a reusable workflow or composite action.
* [ ] **Obsolete Workflow Updates**:
  * [ ] Update `generate_mariadb_examples.yml` to target supported versions (10.11, 11.4, 11.8, 12.3) instead of exclusively EOL versions (10.2→10.9).
  * [ ] Update `generate_mysql_examples.yml` to target supported versions (8.4, 9.7) instead of exclusively EOL versions (5.6, 5.7, 8.0).
  * [ ] Update `pull_request.yml` to test at least one supported MySQL (8.4) and one supported MariaDB (11.4) version alongside legacy versions.
* [ ] **Automated Matrix Synchronization**:
  * [ ] Extend `lts_autobump.pl` to automatically update the CI version matrix in tandem with `mysqltuner.pl` and test suite updates.

### Phase 29: Publish Pipeline Unification [NOT STARTED]

> Eliminates duplication between local and CI publish flows, and harmonizes pre-publish validation.

* [ ] **Unified Pre-Publish Validation Script**:
  * [ ] Factor the pre-publish validation logic (critical file checks, release notes existence, tag/version consistency) into a single reusable script `build/validate_release.sh`.
  * [ ] Refactor `docker_publish.yml` and `publish_release.yml` to call this shared script instead of embedding inline validation.
  * [ ] Harmonize the critical file lists (currently divergent between the two workflows).
* [ ] **Local Docker Publish Deprecation**:
  * [ ] Mark `publishtodockerhub.sh` as deprecated in favor of the `docker_publish.yml` workflow (which includes Buildx, multi-arch, and full validation).
  * [ ] Update `Makefile` `docker_push` target to warn about deprecation and recommend using the CI workflow.

### Phase 30: Build Stack Rationalization [NOT STARTED]

> Simplifies the multi-language build toolchain toward Perl-first consistency with the project's zero-dependency philosophy.

* [ ] **Release Notes Generator Migration (Python → Perl)**:
  * [ ] Rewrite `release_gen.py` (347 lines) in Perl using Core modules only, eliminating the Python 3 runtime dependency from the build stack.
  * [ ] Preserve all current features: changelog parsing, git commit grouping, diagnostic growth indicators, and CLI option delta analysis.
* [ ] **Features Generator Migration (Bash → Perl)**:
  * [ ] Rewrite `genFeatures.sh` (currently a `grep | perl | sort | perl | grep` pipeline) as a pure Perl script to eliminate the shell dependency.
* [ ] **Build Script Header Standardization**:
  * [ ] Standardize all `build/` script headers with a common format including: description, author, dependencies, usage, and exit codes.
* [ ] **EOL Script Consolidation**:
  * [ ] Merge `endoflife.sh` (Bash + curl + jq) functionality into `sync_eol_dates.pl` (already uses HTTP::Tiny), eliminating the `jq` external dependency.

## 🤝 Contribution & Feedback

We welcome community feedback on this roadmap. If you have specific feature requests or want to contribute to a specific phase, please open an issue on our [GitHub repository](https://github.com/jmrenouard/MySQLTuner-perl).
