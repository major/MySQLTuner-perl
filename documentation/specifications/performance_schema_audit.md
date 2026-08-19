---
test_file: tests/pfs_observability.t
---
# Specification: Performance Schema Audit Logic

## Goal

Automatically detect and report if `performance_schema` is disabled during laboratory audits.

## Scenario & Instrumentation Rules

- **PFS Activation Check**: Verifies if `@@performance_schema` is `ON`. If disabled, flags degraded observability for query digests, index usage statistics, and wait event tracking.
- **Top Wait Events Analysis**:
  - Scans `performance_schema.events_waits_summary_global_by_event_name` to classify top latencies into categories:
    - **Disk I/O Contention**: `wait/io/file/innodb/*`, `wait/io/table/sql/handler`
    - **Locking & Concurrency**: `wait/synch/mutex/innodb/*`, `wait/lock/table/sql/handler`, `wait/synch/sxlock/innodb/*`
    - **Replication/Network**: `wait/io/socket/sql/client_connection`

## Auto-Increment Exhaustion Algorithm

To prevent catastrophic application downtime caused by primary key overflow, MySQLTuner computes the headroom ratio for all numeric auto-increment columns:

$$\text{Headroom \%} = \left(\frac{\text{AUTO\_INCREMENT}}{\text{MAX\_INT\_VALUE}}\right) \times 100$$

### Type Threshold Matrix:
| Column Data Type | Signed Max Value | Unsigned Max Value |
| :--- | :--- | :--- |
| `TINYINT` | 127 | 255 |
| `SMALLINT` | 32,767 | 65,535 |
| `MEDIUMINT` | 8,388,607 | 16,777,215 |
| `INT` | 2,147,483,647 | 4,294,967,295 |
| `BIGINT` | $9.22 \times 10^{18}$ | $1.84 \times 10^{19}$ |

- **Warning Threshold**: $\ge 75\%$ capacity used.
- **Critical Alert**: $\ge 90\%$ capacity used (recommends column ALTER to `BIGINT UNSIGNED`).
- **Optimization (Issue #986)**: The query retrieves `COLUMN_TYPE` in the initial `information_schema.TABLES` join to eliminate subsequent per-column lookups.

## Verification

- Validated via `tests/pfs_observability.t`, `tests/unit_workload_traffic.t`, and `tests/repro_pfs_disabled.t`.
- Confirms PFS status checks and auto-increment exhaustion alerts.
