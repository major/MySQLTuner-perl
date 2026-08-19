---
test_file: tests/innodb_redo_log_capacity_logic.t
---
# Specification: Roadmap Phase V - Deep InnoDB Tuning & Safeguarding

## Goal

Provide granular InnoDB tuning recommendations including Workload-based Redo Log capacity, Buffer Pool Instance scaling, and Undo tablespace monitoring.

## Context

MySQLTuner-perl has successfully integrated infrastructure awareness and modern version support (up to 9.x). Phase V aims to go beyond operational tuning into deep storage engine internals and proactive safeguarding for modern high-performance workloads.

## Proposed InnoDB Indicators

### 1. I/O Resource & Flushing Pressure Analysis

* **Metric**: `Innodb_buffer_pool_wait_free` vs `innodb_io_capacity`.
* **Indicator**: Detect if InnoDB is stalling because no clean pages are available in the buffer pool.
* **Recommendation**: Increase `innodb_io_capacity` or `innodb_io_capacity_max` if `wait_free` is non-zero.

### 2. Read-Ahead Efficiency Audit

* **Metric**: `Innodb_buffer_pool_read_ahead_evicted` / `Innodb_buffer_pool_read_ahead`.
* **Indicator**: High eviction rate of read-ahead pages indicates wasted I/O and buffer pool pollution.
* **Recommendation**: Decrease `innodb_read_ahead_threshold` or disable `innodb_random_read_ahead`.

### 3. Purge Lag & History Monitor

* **Metric**: `Innodb_history_list_length`.
* **Indicator**: Large history list length indicates that the purge process cannot keep up with the write workload (MVCC overhead).
* **Recommendation**: Increase `innodb_purge_threads` or review transaction isolation levels.

### 4. Modern Storage Alignment (SSD/NVMe)

* **Check**: `innodb_doublewrite_pages` alignment (128 for MySQL 8.4+).
* **Check**: `innodb_use_fdatasync` (ON for modern Linux kernels to reduce syscall overhead).
* **Check**: `innodb_numa_interleave` consistency with system NUMA topology.
* **Check**: `innodb_flush_neighbors` set to `0` (disabled) for SSD/NVMe flash storage to eliminate unnecessary adjacent page write overhead.
* **Check**: `innodb_page_cleaners` synchronized with `innodb_buffer_pool_instances` to eliminate flush bottlenecks.

### 5. Dynamic Redo Log Capacity (MySQL 8.0.30+ / 8.4 LTS / 9.x)

* **Metric**: `innodb_redo_log_capacity` vs `Innodb_os_log_written`.
* **Indicator**: Replace deprecated `innodb_log_file_size` and `innodb_log_files_in_group` with dynamic online sizing.
* **Sizing Rule**: Redo Log Capacity should accommodate at least 1 to 2 hours of peak write transactions to prevent checkpoint stalling:
  $$\text{Target Redo Capacity} = \left(\frac{\text{Innodb\_os\_log\_written}}{\text{Uptime}}\right) \times 3600 \times 1.5$$

### 6. Temporary & Undo lifecycle (MariaDB 11.4+)

* **Indicator**: Online truncation of temp tablespaces.
* **Recommendation**: Trigger/Suggest `innodb_truncate_temporary_tablespace_now` when temp tablespaces grow beyond a threshold.

## Expected Value

* **Stability**: Reducing I/O stalls and buffer pool pollution.
* **Performance**: Better utilization of NVMe storage and multi-socket CPU (NUMA).
* **Portability**: Maintaining the single-file architecture while deep-diving into PFS/Status metrics.

## Verification

- Validated via `tests/innodb_redo_log_capacity_logic.t` and `tests/unit_innodb_internals.t`.
- Confirms InnoDB buffer pool and redo log sizing recommendations.
