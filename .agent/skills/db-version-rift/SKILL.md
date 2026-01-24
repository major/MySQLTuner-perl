---
trigger: always_on
description: Mapping of critical differences between MySQL and MariaDB versions for cross-compatible diagnostics.
category: skill
---
# Database Version Rift Skill

## Description

This skill maps critical differences between MySQL and MariaDB versions to help developers implement cross-compatible diagnostics in MySQLTuner.

## Replication Commands

| Feature | MySQL < 8.0.22 / MariaDB < 10.5 | MySQL >= 8.0.22 | MariaDB >= 10.5 |
| :--- | :--- | :--- | :--- |
| **Show Slave Status** | `SHOW SLAVE STATUS` | `SHOW REPLICA STATUS` (Preferred) | `SHOW REPLICA STATUS` (Preferred) |
| **Show Slave Hosts** | `SHOW SLAVE HOSTS` | `SHOW REPLICA HOSTS` | `SHOW REPLICA HOSTS` |

**Strategy:**
Detect version first. If version >= breakpoint, try `REPLICA`, fall back to `SLAVE` if error or empty (though strictly version check is safer).

## Authentication & Security

| Feature | MySQL 5.7 / MariaDB | MySQL 8.0+ |
| :--- | :--- | :--- |
| **PASSWORD() function**| Available | **REMOVED** (Use SHA2 functions or app-side hashing) |
| **User table** | `mysql.user` (authentication_string since 5.7) | `mysql.user` (authentication_string) |

**Strategy:**
For password checks in MySQL 8.0+, do strictly SQL-based checks (e.g., length of auth string) or avoid logic that depends on hashing input strings via SQL.

## Information Schema Differences

### `information_schema.TABLES`

- Usually stable, but check `Data_free` interpretation across engines.

### `performance_schema`

- **MySQL 5.6+**: Defaults enabled (mostly).
- **MariaDB 10.0+**: Defaults varying.
- **Check**: Always verify `performance_schema = ON` before querying tables.

## System Variables (Renames)

| Legacy Name | Modern Name (MySQL 8.0+) | Note |
| :--- | :--- | :--- |
| `tx_isolation` | `transaction_isolation` | Check both or `||` them. |
| `query_cache_size` | *Removed* | Removed in MySQL 8.0 |

**Strategy:**
Use the `mysqltuner.pl` valid variable abstraction or check for existence before using.

## MariaDB vs MySQL Divergence

- **Thread Pool**:
  - **MariaDB**: Built-in, specific vars (`thread_pool_size`, `thread_pool_oversubscribe`).
  - **MySQL**: Enterprise only or Percona specific.
  - **Action**: Check `version_comment` or `version` string for "MariaDB" before recommending thread pool settings.

- **Aria Engine**:
  - Specific to MariaDB (replacement for MyISAM for system tables).
  - Don't tune `aria_pagecache_buffer_size` on Oracle MySQLand Percona version.
