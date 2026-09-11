# Issue #1005: AI Skill Specification — diagnose_replication_lag

**Type:** Feature / AI Skill  
**Component:** `build/mcp_server.py`, `.agent/skills/diagnose-replication-lag/SKILL.md`, `tests/unit_skill_replication.t`  
**Assignee:** jmrenouard  
**Labels:** `mcp`, `skill`, `replication`, `reliability`, `gtid`  

## 🎯 Description & Objectives
Implement the specialized AI Diagnostic Skill `diagnose_replication_lag` in the MySQLTuner MCP server.
This skill allows LLM agents and automated site reliability engineers to diagnose asynchronous and semi-synchronous replication anomalies, parallel worker saturation, IO/SQL thread failures, and GTID synchronization gaps across MySQL 5.7/8.0/8.4 and MariaDB 10.5/10.11/11.4 topologies.

### Diagnostic Algorithms
1. **Topology & Status Detection**:
   - Executes `SHOW REPLICA STATUS` with fallback to `SHOW SLAVE STATUS`.
   - Distinguishes Standalone vs Primary vs Replica node roles.
2. **Health Assessment**:
   - `HEALTHY`: IO & SQL threads running, `Seconds_Behind_Master` $\le \text{max\_lag}$.
   - `DEGRADED_LAG`: IO & SQL threads running, but `Seconds_Behind_Master` $> \text{max\_lag}$.
   - `THREAD_FAILED`: `Slave_IO_Running` or `Slave_SQL_Running` is `No` with Last_Error details.
   - `NOT_A_REPLICA`: No replication source configured.
3. **Multi-Threaded Worker Optimization**:
   - When replication lag is detected on single-threaded workers (`slave_parallel_workers == 0`), recommend `SET GLOBAL replica_parallel_workers = 4` and `SET GLOBAL replica_parallel_type = 'LOGICAL_CLOCK'`.

## 🧪 Acceptance Criteria
- [x] Skill registered in MCP Tools Catalog as `diagnose_replication_lag` with strict JSON Schema.
- [x] Returns structured metrics: `io_running`, `sql_running`, `lag_seconds`, `gtid_mode`, `parallel_workers`, `last_error`, and actionable recommendations.
- [x] Unit test `tests/unit_skill_replication.t` covering healthy, lagged, thread-failed, and standalone topologies.
- [x] Documentation in `.agent/skills/diagnose-replication-lag/SKILL.md`.
