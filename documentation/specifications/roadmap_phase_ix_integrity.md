# Specification: Roadmap Phase IX - Data Integrity & Checksum Verification

## Context

Ensuring data integrity at rest and during transit is paramount for mission-critical databases. Phase IX focuses on auditing the activation and algorithm strength of checksums across the entire storage and replication pipeline.

## Proposed Data Integrity Indicators

### 1. InnoDB Page Integrity Audit

* **Metric**: `innodb_checksum_algorithm`.
* **Indicator**: Verify if modern algorithms (`CRC32` or `full_crc32`) are used instead of legacy ones.
* **Recommendation**: Suggest upgrading to `full_crc32` for MariaDB 10.5+ and ensure `innodb_checksums` is not disabled.

### 2. Log Integrity Protection

* **Metric**: `innodb_log_checksums`.
* **Metric**: `innodb_log_checksums`.
* **Indicator**: Verification that redo log blocks are protected by checksums.
* **Check**: Alert if disabled, as it can lead to undetected log corruption during recovery.

### 3. Binary Log Transmission & Storage Safety

* **Check**: Alignment with `innodb_checksum_algorithm`.

## Expected Value

* **Early Corruption Detection**: Identifying hardware or filesystem issues before they cause permanent data loss.

* **Recovery Confidence**: Ensuring that redo and binary logs are reliable for crash recovery and point-in-time recovery.
* **Replication Safety**: Preventing the propagation of silent corruption across the cluster.
