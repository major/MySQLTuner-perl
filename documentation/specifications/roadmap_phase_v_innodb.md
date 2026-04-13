# Specification: Roadmap Phase V - Deep InnoDB Tuning & Safeguarding

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

### 5. Temporary & Undo lifecycle (MariaDB 11.4+)

* **Indicator**: Online truncation of temp tablespaces.
* **Recommendation**: Trigger/Suggest `innodb_truncate_temporary_tablespace_now` when temp tablespaces grow beyond a threshold.

## Expected Value

* **Stability**: Reducing I/O stalls and buffer pool pollution.
* **Performance**: Better utilization of NVMe storage and multi-socket CPU (NUMA).
* **Portability**: Maintaining the single-file architecture while deep-diving into PFS/Status metrics.
