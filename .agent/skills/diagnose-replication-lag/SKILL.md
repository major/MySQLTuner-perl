---
name: diagnose_replication_lag
description: Diagnoses MySQL and MariaDB replication latency, IO/SQL thread failures, GTID synchronization, and parallel worker saturation.
---

# AI Skill: Database Replication Latency & Health Diagnostics

## 🧠 Purpose & Operational Objectives
The `diagnose_replication_lag` skill allows AI agents to monitor binary log transport latency, parallel worker thread concurrency, and replication thread failures in master-replica and multi-source topologies.

## 📋 Preconditions & Context
- Server configured as a MySQL or MariaDB replica/slave node.
- Read-only queries executed (`SHOW REPLICA STATUS` or `SHOW SLAVE STATUS`).
- Compatible with legacy (`SLAVE`) and modern (`REPLICA`) keywords.

## 🛠️ Input Parameters
| Parameter | Type | Required | Default | Description |
|:---|:---|:---|:---|:---|
| `max_acceptable_lag_seconds` | integer | No | `30` | Threshold in seconds above which replication is considered degraded. |
| `channel_name` | string | No | `""` | Multi-source replication channel identifier (optional). |

## 📊 Status Evaluation
1. **NOT_A_REPLICA**: No replication configuration detected on the instance.
2. **THREAD_FAILED**: `Slave_IO_Running != 'Yes'` or `Slave_SQL_Running != 'Yes'`. Returns exact SQL/IO error code and message.
3. **DEGRADED_LAG**: Threads running, but `Seconds_Behind_Master > max_acceptable_lag_seconds`.
4. **HEALTHY**: Both threads running and latency within acceptable bounds.

## 🛡️ Guardrails & Remediation
- Automatically suggests parallel worker thread tuning (`replica_parallel_workers`, `replica_parallel_type = 'LOGICAL_CLOCK'`) to absorb heavy write streams.
- Provides rollback commands for all global variables.
