# Issue #1026: High Availability & Replication Auto-Discovery (Phase 22)

**Type:** Feature / HA Architecture Discovery  
**Component:** `mysqltuner.pl`, `tests/unit_topology_autodiscovery.t`  
**Assignee:** jmrenouard  
**Labels:** `ha`, `galera`, `innodb_cluster`, `replication`, `topology`, `discovery`  

## 🎯 Description & Objectives
MySQL architectures span standalone instances, synchronous Galera/PXC clusters, MySQL InnoDB Clusters (Group Replication), and classic asynchronous/semi-sync source-replica topologies.

This phase implements automated topology discovery (`discover_cluster_topology()` in `mysqltuner.pl`) that:
1. Identifies the operational topology (`Standalone`, `Galera Cluster / PXC`, `InnoDB Cluster / Group Replication`, `Replication Source`, `Replication Replica`).
2. Extracts Galera cluster members from `wsrep_incoming_addresses` and validates quorum size (> 2 nodes).
3. Analyzes replica lag (`Seconds_Behind_Master` / `Seconds_Behind_Source`), IO/SQL thread states.
4. Stores findings in `$result{'Topology'}` and pushes actionable recommendations to `@generalrec` and `@sysrec`.

## 🧪 Acceptance Criteria
- [x] Subroutine `discover_cluster_topology()` implemented in `mysqltuner.pl`.
- [x] Accurately classifies Galera, Group Replication, Source, Replica, and Standalone.
- [x] Comprehensive TAP unit test `tests/unit_topology_autodiscovery.t` covering all topology archetypes.
