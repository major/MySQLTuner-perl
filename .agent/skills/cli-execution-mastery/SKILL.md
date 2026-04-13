---
trigger: explicit_call
description: Mastery of MySQLTuner CLI options for connection and authentication.
category: skill
---
# CLI Execution Mastery Skill

## 🧠 Rationale

Mastering the CLI options of `mysqltuner.pl` allows for seamless execution across diverse environments while maintaining security and leveraging existing configurations.

## 🛠️ Implementation

### 1. Connection Discovery & Targeting

| Target Type | Primary Command/Options |
| :--- | :--- |
| **Local Socket** | `perl mysqltuner.pl` (Default) \| `--socket=/path/to/mysql.sock` |
| **Remote Host** | `perl mysqltuner.pl --host=1.2.3.4 --port=3306` |
| **Container** | `perl mysqltuner.pl --container=container_name_or_id` |
| **Cloud/Azure** | `perl mysqltuner.pl --cloud --azure` |

### 2. Authentication Strategies

> [!IMPORTANT]
> Avoid passing passwords directly via `--pass` on the command line to prevent exposure in process lists.

- **Preferred: `.my.cnf` Usage**
  - Use `--defaults-file=/path/to/.my.cnf` to point to a specific configuration file.
  - The script automatically respects common paths if not specified.

- **Environment Variables**
  - Use `--userenv=MY_USER_VAR` and `--passenv=MY_PASS_VAR` to leverage pre-set credentials.

- **Password Files**
  - Use `--passwordfile=/path/to/passwords.txt` for batch security auditing.

### 3. Execution Contexts

- **Standard Verbose Run**: `perl mysqltuner.pl --verbose` (Recommended for full diagnostics).
- **Silent Mode**: `perl mysqltuner.pl --silent` (Useful for automated data collection).
- **JSON Output**: `perl mysqltuner.pl --json` or `--prettyjson` (For integration with other tools).

### 4. Debugging Connections

If connection fails, use these flags to diagnose:

- `--debug`: Enables full debug output.
- `--dbgpattern='.*'`: Filters debug information with regex.
- Verify `mysqlcmd` path if custom binaries are used: `--mysqlcmd=/usr/local/bin/mysql`.

### 5. MariaDB InnoDB Variable Compatibility

As MariaDB evolves, several InnoDB system variables have been removed or deprecated. `mysqltuner.pl` detects these to avoid legacy configuration overhead.

| Parameter | Removed/Deprecated In | Note/Replacement |
| :--- | :--- | :--- |
| `have_innodb` | Removed 10.0 | Use `SHOW ENGINES` or `I_S.PLUGINS`. |
| `innodb_adaptive_flushing_method` | Removed 10.0 | Replaced by MySQL 5.6 flushing logic. |
| `innodb_checksums` | Removed 10.0 | Use `innodb_checksum_algorithm`. |
| `innodb_stats_sample_pages` | Removed 10.5.0 | Use `innodb_stats_transient_sample_pages`. |
| `innodb_file_format` / `_check` / `_max` | Removed 10.6.0 | Antelope and Barracuda are legacy concepts. |
| `innodb_large_prefix` | Removed 10.6.0 | Always enabled in newer versions. |
| `innodb_locks_unsafe_for_binlog` | Removed 10.6.0 | No longer supported. |
| `innodb_prefix_index_cluster_optimization` | Deprecated 10.10 | Always enabled now. |

### 6. MySQL InnoDB Variable Compatibility

| Parameter | Removed/Deprecated In | Note/Replacement |
| :--- | :--- | :--- |
| `innodb_locks_unsafe_for_binlog` | Removed 8.0 | Use `READ COMMITTED` isolation level instead. |
| `innodb_support_xa` | Removed 8.0 | XA support is now always enabled. |
| `innodb_file_format` family | Removed 8.0 | `Barracuda` is the only supported format. |
| `innodb_large_prefix` | Removed 8.0 | Always enabled for `Barracuda`. |
| `tx_isolation` / `tx_read_only` | Removed 8.0 | Use `transaction_isolation` / `transaction_read_only`. |
| `innodb_undo_logs` | Removed 8.0 | Replaced by `innodb_rollback_segments`. |
| `innodb_undo_tablespaces` | Removed 9.0 | Managed automatically now. |
| `innodb_log_file_size` | Removed 9.0 | Replaced by `innodb_redo_log_capacity`. |
| `innodb_api_...` variables | Removed 8.4 | Memcached-related variables removed. |

## ✅ Verification

- Run `perl mysqltuner.pl --help` to confirm availability of these options.
- Use `execute_system_command` to test connectivity with specific flags in the target environment.
