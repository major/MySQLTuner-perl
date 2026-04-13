# MySQLTuner-perl Roadmap

This document outlines the strategic direction and future development plans for MySQLTuner-perl. Our mission is to provide the most stable, portable, and reliable performance tuning advisor for MySQL-compatible databases.

## 👤 Governance

To ensure consistency and high-density development, the following roles are defined for roadmap orchestration:

* **Owner**: [Jean-Marie Renouard](https://github.com/jmrenouard) (@jmrenouard) - Ultimate authority on the project, constitution, and core mission.
* **Product Manager**: **Antigravity (AI Agent)** - Responsible for backlog management, specification design, and execution tracking of the roadmap items.
* **Release Manager**: **Antigravity (AI Agent)** - Responsible for technical validation, testing orchestration, and unified release cycle execution.

## 🌟 Strategic Pillars

1. **Production Stability & Safety**: All recommendations must be verified and safe for production.
2. **SQL Modeling & Schema Design**: Beyond operational tuning, provide deep insights into database architecture.
3. **Zero-Dependency Portability**: Maintain single-file architecture with core-only dependencies.
4. **Modern Ecosystem Support**: Seamless integration with Containers (Docker/K8s) and Cloud providers.

---

## 🚀 Development Phases

### Phase 1: Stabilization & Observability (v2.8.31 - v2.8.33) [COMPLETED]

* [x] **[Metadata-Driven CLI Options](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/cli_metadata_refactor.md)**: Refactored option parsing to centralize defaults, validation, and documentation.
* [x] **Enhanced SQL Modeling**: Expanded diagnostic checks for Foreign Key type mismatches, missing indexes, and schema sanitization.
* [x] **[Structured Error Log Ingestion](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/error_log_pfs.md)**: Supported `performance_schema.error_log` for diagnostic ingestion (MySQL 8.0+).
* [x] **Refined Reporting**: Improved data richness in the "Modeling Analysis" tab.

### Phase 2: Advanced Diagnostics (v2.8.34 - v2.8.38) [COMPLETED]

| Item | Status |
| :--- | :--- |
| **System Call Optimization** | [x] Replaced `awk`, `grep`, `hostname`, `uname`, `sysctl` with native Perl. |
| **Native /proc Parsing** | [x] Implemented native parsing for `cpuinfo`, `meminfo`, `swappiness`. |
| **[Index Audit 2.0](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/index_checks_pfs.md)** | [x] Integrated `performance_schema` for redundant/unused index detection. |
| **Observability Log Ingestion** | [x] Support for `syslog`, `journald`, and `performance_schema.error_log`. |
| **Transactional Contention** | [x] Detect isolation levels and long-running transactions. |
| **Buffer Pool Advisory** | [x] More granular analysis of InnoDB Redo Log Capacity based on RAM/Writes. |

### Phase 3: Automation & Ecosystem [COMPLETED]

* [x] **Infrastructure-Aware Tuning**: Detect storage types (NVMe/SSD) and hardware architectures (ARM64/Graviton).
* [x] **[MySQL 9.x Full Compatibility](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/mysql_9_x_support.md)**: Support for removed variables and `mysql_native_password` elimination.
* [x] **[Authentication Plugin Auditing](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/auth_plugin_security_checks.md)**: Detect insecure plugins (SHA-1 based `mysql_native_password`) and recommend migration paths (`caching_sha2_password`, `ed25519`).
* [x] **Sysbench Metrics Integration**: Automated baseline capture and performance comparison within the report.
* [x] **Multi-Cloud Autodiscovery**: Automated detection of RDS, GCP, and Azure specific performance flags and optimizations.
* [x] **Query Anti-Pattern Detection**: Use `performance_schema` to identify non-SARGable queries and `SELECT *` abuse.
* [/] **Modular Reporting Engine**: (In Progress) Refactor Jinja2 templates for dynamic section injection.
* [/] **Historical Trend Analysis**: (Experimental) Allow the script to ingest previous run data to identify performance regressions.

### [Phase 4: Advanced Intelligence & Ecosystem](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/roadmap_phase_iv_intelligence.md)

* [/] **Smart Migration LTS Advisor**:
  * [x] Automated pre-upgrade risk reports (variable removal, deprecation notices).
  * [ ] Compatibility audit for SQL modes, character sets, and version-specific engine changes.
* [x] **Weighted Health Score**:
  * [x] Unified KPI (0-100) aggregating findings from Security, Performance, and Resilience.
  * [ ] Comparative scoring against previous runs or established industry baselines.
* [/] **Predictive Capacity Planning**:
  * [ ] Data growth forecasting based on binlog throughput and table statistics.
  * [x] Memory headroom analysis for traffic peak forecasting.
* [/] **Cluster & Replication Intelligence**:
  * [x] Root cause analysis for replication lag (IO/SQL thread contention).
  * [ ] GTID consistency checks and multi-source replication tuning.
* [/] **Security Hardening 2.0**:
  * [ ] Version-based CVE exposure detection (community-fed database).
  * [x] Advanced encryption-at-rest (TDE) and SSL/TLS cipher suite validation.
* [/] **Guided Auto-Fix Engine**:
  * [ ] Interactive mode to simulate configuration changes.
  * [x] Generation of ready-to-use `SET GLOBAL` or `my.cnf` snippets.

### Phase 5: Deep Engine Tuning & Safeguarding [([Specification](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/roadmap_phase_v_innodb.md))]

* [ ] **InnoDB Internals 3.0**:
  * [/] **I/O Pressure & Flushing Advisor**: Combined analysis of `innodb_io_capacity`, `Innodb_buffer_pool_wait_free`, and adaptive flushing metrics to prevent I/O stalls.
  * [ ] **Read-Ahead Efficiency Audit**: Measure `Innodb_buffer_pool_read_ahead_evicted` vs `Innodb_buffer_pool_read_ahead` to optimize `innodb_read_ahead_threshold`.
  * [ ] **Deadlock & Contention Analytics**: Historic deadlock tracking via `performance_schema` with specific table-level contention reports.
  * [ ] **Modern Storage Alignment**: Deep audit of `innodb_doublewrite_pages` alignment (128 for MySQL 8.4+), `innodb_use_fdatasync` for syscall reduction, and `innodb_flush_method`.
* [ ] **Resource Isolation & Multi-Tenancy**:
  * [ ] **NUMA-Aware Memory Allocation**: Verification of `innodb_numa_interleave` and system memory controller balance.
  * [ ] **Temp & Undo Lifecycle Manager**: Proactive advisory for MariaDB temporary tablespace online truncation (`innodb_truncate_temporary_tablespace_now`) and MySQL undo health.
* [ ] **Adaptive Intelligence**:
  * [ ] **Read-Ahead & Change Buffer Optimization**: Dynamic recommendation to disable legacy features (`innodb_change_buffering`, `innodb_adaptive_hash_index`) based on workload patterns.
  * [ ] **Purge Lag Prevention**: Automated detected of purge lag (`Innodb_history_list_length`) and recommendation for `innodb_purge_threads` scaling.

### [Phase 6: High Availability & InnoDB Cluster](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/roadmap_phase_vi_innodb_cluster.md)

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

### [Phase 7: Modern Replication & GTID Mastery](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/roadmap_phase_vii_replication.md)

* [ ] **Data Consistency & GTID Integrity**:
  * [ ] **GTID Gap Analysis**: Detection of non-contiguous global transaction identifiers and missing transactions across the replication chain.
  * [ ] **Consistency Enforcement Audit**: Verification of `enforce_gtid_consistency`, `gtid_mode=ON`, and `binlog_format=ROW` for all nodes.
* [ ] **Throughput & Parallelism Optimization**:
  * [ ] **Parallel Applier (MTR) Tuning**: Advanced monitoring of worker thread saturation and busy-wait distribution.
  * [ ] **Dependency Tracking Analysis**: Verification of dependency tracking type (`COMMIT_ORDER` vs `WRITESET` in MySQL) and `slave_parallel_mode` (MariaDB).
* [ ] **Network & Durability Enhancements**:
  * [ ] **Binary Log Compression Audit**: Monitoring efficiency and CPU impact of `binlog_transaction_compression` (MySQL 8.0.20+).
  * [ ] **Binlog Cache Deep-Dive**: Analysis of `Binlog_cache_disk_use` ratio to detect large transactions causing disk stalls.
  * [ ] **Semi-Sync Safety Check**: Dynamic analysis of semi-synchronous wait points (`AFTER_SYNC` vs `AFTER_COMMIT`) and fallback triggers.
  * [ ] **Multi-Source Channel Monitoring**: Full observability for multi-master and multi-channel replication topologies.

### [Phase 8: Advanced Galera Cluster 4 & PXC 8.0](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/roadmap_phase_viii_galera.md)

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

### [Phase 9: Data Integrity & Checksum Verification](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/roadmap_phase_ix_integrity.md)

* [ ] **Storage Engine Protection**:
  * [/] **InnoDB Page Integrity Audit**: Verification of `innodb_checksum_algorithm` strength (`full_crc32` for MariaDB 10.5+, `CRC32` for MySQL) and ensuring `innodb_checksums` is active.
  * [ ] **Redo Log Safety Check**: Monitoring of `innodb_log_checksums` to prevent undetected recovery from corrupted logs.
  * [ ] **Doublewrite Consistency**: Alignment check between doublewrite buffer activity and storage atomic write capabilities.
* [ ] **Replication Pipeline Validation**:
  * [ ] **Binlog Event Integrity**: Verification of `binlog_checksum` (CRC32) across the topology and alignment with storage algorithms.
  * [ ] **End-to-End Verification Audit**: Analysis of `source_verify_checksum` and `replica_sql_verify_checksum` settings.
  * [ ] **Relay Log Hardening**: Verification of checksum validation before transaction application on replicas.

### Phase 10: Workload Analysis & Traffic Profiling

* [ ] **Query Performance Profiling**:
* [ ] **Wait Event Fingerprinting**: Aggregation of `performance_schema` wait events to identify the primary database bottleneck (CPU, disk, lock, network).
* [ ] **Workload Characterization**: Automated classification of the database as Read-Heavy, Write-Heavy, or Mixed based on I/O ratios.
* [ ] **Metadata & Object Lifecycle**:
* [ ] **Table Churn & Fragmentation Advisor**: Identification of tables with frequent DML that require periodic `OPTIMIZE TABLE`.
* [ ] **Auto-Increment Exhaustion Audit**: Monitoring of large tables for potential auto-increment overflow (especially 32-bit integers).

### [Phase 11: Advanced Log Parser & Lock Monitoring](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/roadmap_phase_xi_log_parser.md)

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

### [Phase 12: Sectional Global Indicators & KPIs](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/roadmap_phase_xii_sectional_indicators.md)

* [ ] **Unified Health Dashboard**:
  * [ ] **Sectional Health Scoring**: Implementation of a 0-100 KPI for each major diagnostic area (Storage Engine, Security, Replication, SQL Modeling).
  * [ ] **Critical Findings Executive Summary**: Automated prioritization of the top 3 items per section with color-coded badges (🔴 Critical, 🟡 Finding, 🟢 Optimal).
* [ ] **Efficiency & Resource Mapping**:
  * [ ] **Throughput Efficiency Index**: Real-time ratio analysis of logical work (Queries/sec) vs physical resource consumption (`Innodb_buffer_pool_read_requests`).
  * [ ] **Resource Saturation Heatmap**: Visual representation of proximity to system limits (CPU/MEM/IO/Connections).
* [ ] **Comparative Insights**:
  * [ ] **Historical Performance Deltas**: Sectional trend analysis identifying areas of performance regression or improvement based on previous run data.

### [Phase 13: Export Optimization & Dumpdir Hardening](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/documentation/specifications/roadmap_phase_xiii_export_optimization.md)

* [ ] **Export Performance Safeguards**:
  * [ ] **Default Row Limit**: Implementation of a 50,000 rows default limit for all `dumpdir` exports to prevent database slowdowns.
  * [ ] **Configurable Quotas**: Addition of `--dump-limit` option to allow user-defined row overrides.
* [ ] **Metadata & Durability**:
  * [ ] **Manifest Generation**: Automated generation of `manifest.json`/`metadata.txt` for better traceability of offline diagnostic snapshots.
  * [ ] **I/O Latency Monitoring**: Real-time tracking of export duration per object with notices for slow disk subsystems.
* [ ] **Compression & Efficiency**:
  * [ ] **On-the-fly Compression**: Support for compressed `.gz` exports to minimize disk footprint in container/limited-storage environments.

## 🤝 Contribution & Feedback

We welcome community feedback on this roadmap. If you have specific feature requests or want to contribute to a specific phase, please open an issue on our [GitHub repository](https://github.com/jmrenouard/MySQLTuner-perl).
