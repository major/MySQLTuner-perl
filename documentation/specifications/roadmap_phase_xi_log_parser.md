# Specification: Roadmap Phase XI - Advanced Log Parser & Lock Monitoring

## Context

While MySQLTuner currently ingests basic error logs, Phase XI aims to transform log analysis into a proactive diagnostic tool by correlating configuration with runtime error patterns and deep-diving into InnoDB locking instrumentation.

## Proposed Log & Lock Indicators

### 1. InnoDB Lock Instrumentation Audit

- **Metric**: `innodb_print_all_deadlocks`.
- **Indicator**: Detect if deadlock logging is active for proactive troubleshooting.
- **Metric**: `innodb_status_output` and `innodb_status_output_locks`.
- **Indicator**: Monitor if the engine is periodically splashing status to logs (useful for post-mortem analysis of stalls).

### 2. Semantic Error Log Tracer

- **Pattern Recognition**:
  - **OOM Alerts**: Detect `Out of memory` patterns to correlate with `innodb_buffer_pool_size` vs System RAM.
  - **Semaphore Wait Stalls**: Identify `InnoDB: semaphore wait` entries indicating I/O subsystem saturation or internal OS contention.
  - **Table Cache Saturation**: Detect `too many open files` or `open_files_limit` warnings.
  - **Crash & Corruption Recovery**: Identify `is marked as crashed` (MyISAM) or `checksum mismatch` (InnoDB) patterns.

### 3. Log Management Best Practices

- **Metric**: `log_error_verbosity` (MySQL 8.0+) / `log_warnings` (MariaDB).
- **Indicator**: Ensure the log level is appropriate for the environment (Audit vs Performance).
- **Log Rotation Check**: Verify if logs are being rotated to prevent OOM/Disk issues during parsing.

### 4. Correlation Engine (Experimental)

- Logic to link error log timestamps with Performance Schema wait events or high CPU load detected during the script execution.

## Expected Value

- **Faster Root Cause Analysis**: Moving from "something is slow" to "InnoDB is stalling on I/O semaphores".
- **Proactive Corruption Warning**: Detecting disk failures before the entire database becomes unavailable.
- **Resource Limit Visibility**: Identifying OS-level constraints (file descriptors, memory) affecting the DB.
