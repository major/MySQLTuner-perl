# Specification: Roadmap Phase XIV - Interactive Multi-Page HTML Reports & Detailed Exports

- **Feature Name**: Interactive Multi-Page HTML Reports & Detailed Exports
- **Status**: Approved
- **Created Date**: 2026-06-25
- **Last Updated**: 2026-07-05

## 🧠 Rationale

As MySQLTuner-perl reports grow in complexity, a single long scrolling page of recommendations is no longer sufficient for database administrators and managers. To align with advanced diagnostic tooling (such as pgBadger for PostgreSQL or the MT-reporter suite) while keeping a native, zero-dependency, single-file Perl architecture, the built-in HTML report (`--reportfile`) must deliver a high level of information, visual graphs, and actionable remediation steps.

This specification details the structure, indicators, and formatting of the multi-page HTML report generated natively by `mysqltuner.pl`, drawing inspiration from pgBadger's multi-dimensional telemetry, query metrics, locking analytics, and event/error distributions.

---

## 🛠️ User Scenarios

### Scenario 1: Executive Review of Database Health
A database manager runs MySQLTuner to get a quick summary. They open the generated HTML report and see a **Summary Dashboard Page** with a circular health gauge, key KPIs, resource saturation indicators, and the top findings across all areas. They do not have to dig through technical logs to assess general health.

### Scenario 2: Topic-Specific Deep Dive with Graphs
A database administrator (DBA) is troubleshooting InnoDB performance. They open the report, click on the **Storage Engines & InnoDB** tab, and view:
- An SVG chart of the buffer pool hit rate.
- A table listing InnoDB status variables, current values, and recommended settings.
- A prioritized list of recommendations for InnoDB.

### Scenario 3: Query & Locking Performance Troubleshooting
A DBA identifies performance degradation and navigates to the **Queries & Top Queries** tab to locate the most resource-intensive normalized query statements. In the **Locks & Latency** tab, they trace wait histograms and check for deadlock occurrences without needing to parse raw error logs or run ad-hoc command-line queries.

### Scenario 4: Exporting Raw Diagnostic Data to CSV
A developer wants to import the parsed database metrics into Excel to perform a custom analysis. They go to the report's **Data Export** tab, see options to download separate CSVs (e.g., variables, status, schema findings, security settings), click "Download CSV", and instantly save the files locally.

---

## 📋 Level of Information & Schema Specification

The native HTML report is structured as an interactive SPA (Single Page Application) with the following detailed metrics and sections:

### 1. Dashboard (Summary View)
- **Circular Health Gauge**: SVG-based animated indicator showing overall score (0-100) with dynamic status colors (Optimal, Good, Action Required).
- **Category Scores**: Structured cards showing metrics for Performance, Security, and Resource Saturation.
- **System Metadata Banner**: Quick facts about the target database (Version, Port, Uptime, Host name, Concurrency).
- **Traffic Overview**: Simple dashboard indicators representing queries/sec (QPS), average throughput (bytes received/sent per second), and Select vs Write ratio.

### 2. System & Memory Analytics
- **OS Resource Saturation**: Detailed breakdown of physical RAM vs. swap usage.
- **Per-Thread & Global Allocation**: Graph representing maximum possible memory allocation compared to physical limits.

### 3. Connections & Sessions
- **Connection Capacity**: Maximum concurrent connections vs. highest historical usage.
- **Cache Hit Rates**: Thread cache hit rate and connection abort percentages.
- **Concurrency & Client Distribution**: Established connections grouped by user, host, or database (when Performance Schema or processlist snapshots are available).

### 4. Queries & Execution Analytics (pgBadger-Inspired)
- **Query Types Distribution**: Visual breakdown of query categories (SELECT, INSERT, UPDATE, DELETE, REPLACE, admin/DDL operations).
- **Prepared Statements Utilization**: Ratio of prepared/executed statements vs. raw dynamic SQL.
- **Query Hits & Misses**: Analysis of query cache hits (where applicable) and database read/write ratios.

### 5. Top Queries & Latency Diagnostics (pgBadger-Inspired)
- **Slowest Queries**: Top N slowest query statements with execution times and user/host origin.
- **Time-Consuming Queries**: Normalized query patterns (with placeholders) sorted by cumulative execution time.
- **Most Frequent Queries**: Most frequent query patterns sorted by call counts with execution statistics (min, max, mean, stddev).
- **Disk Spill Queries**: Queries that triggered the creation of temporary tables on disk.

### 6. Locks & Latency Analytics (pgBadger-Inspired)
- **Lock Saturation**: Table locks immediate vs. waited ratios, showing locking overhead.
- **Row-Level Locking**: Cumulative row lock wait counts, total lock wait duration, and average row lock wait times.
- **Deadlock Analysis**: Captured deadlock occurrences with timestamps, involved threads, and offending transaction details.

### 7. Temporary Tables & Memory Spills (pgBadger-Inspired)
- **Temporary Tables Metrics**: Ratio of memory-based temporary tables to disk-based temporary tables.
- **Temporary Table Activity**: Time-series estimation of temporary table creation rates.

### 8. Storage Engines & InnoDB Forensics
- **Storage Breakdown**: Comprehensive overview of enabled engines.
- **InnoDB Engine Detailed Diagnostics**:
  - Buffer pool instances and chunk size alignment status (Aligned vs. Not Aligned).
  - Page usage details (Total/Free/Used) converted into bytes.
  - Log capacity or file size details (including total log size, group size, and log-to-buffer pool ratio).
  - Concurrency parameters (`innodb_thread_concurrency`) and read buffer efficiency.
  - Hourly InnoDB OS log write workload rate.

### 9. SQL Modeling & Schema Audit
- **User Databases Size Distribution**: Schema name, table counts, rows count, data size, index size, and total size.
- **Fragmented Tables Details**: Schema, table, engine type, free space (MiB), and auto-generated defragmentation SQL queries (`ALTER TABLE ... FORCE` or `OPTIMIZE TABLE ...`).
- **Tables Without Primary Keys**: Detailed list of schemas and tables missing a PK with warning descriptions.
- **Redundant & Unused Indexes**: List of duplicate or non-queried indexes along with drop queries (`ALTER TABLE ... DROP INDEX ...`).

### 10. Security & CVE Exposures
- **Authentication Plugin Audit**: Detailed validation of user authentication plugins against the security support matrix.
- **SSL/TLS Ciphers**: Verification of transport encryption rules and required SSL connection protocols.
- **CVE Database Analysis**: Structured list of matching CVE vulnerability records based on the target MySQL/MariaDB version.

### 11. Replication & Galera Cluster Status
- **Replication Topology**: Standalone vs. Master/Slave relationship, replication lag times, and binlog formats.
- **Galera Synchronization**: Status of clustering synchrony and Galera node metrics.

### 12. Error Logs & Events Audit (pgBadger-Inspired)
- **Log Events Summary**: Total counts of Errors, Warnings, and Notes parsed from the server error log (`--log-error`).
- **Event Distribution**: Hourly graph of warning and error events.
- **Frequent Log Signatures**: Top recurring messages or diagnostic alerts in the error logs.

### 13. Integrated Data Export & Actions
- **rem_queries (Actionable Remediations)**: Ready-to-copy SQL and configuration snippets.
- **Dynamic CSV Downloads**: Inline browser-generated CSV files (prefixed with host, version, and timestamp) for databases, tables, variables, and status metrics.

---

## 🔬 Verification Plan

### Automated Tests
1. **Perl Syntax Validation**: The HTML generation block must be warning-free under `perl -cw mysqltuner.pl`.
2. **Unit Test Assertions**: [tests/html_report.t](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/tests/html_report.t) must mock database status variables, schema lists, and verification logs, asserting that the generated HTML file matches the target SPA layout regex patterns.

### Manual Verification
1. Generate the HTML report:
   ```bash
   perl mysqltuner.pl --reportfile=test_report.html
   ```
2. Open the file in a standard browser environment and assert that:
   - All interactive tabs (Dashboard, Storage, Modeling, Security, Queries, Locks, Events, etc.) function offline.
   - All SVG charts and gauges load and format correctly.
   - The CSV download buttons trigger local downloads with the correct format headers.
