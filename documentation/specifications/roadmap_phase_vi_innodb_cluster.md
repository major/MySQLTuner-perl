# Specification: Roadmap Phase VI - High Availability & InnoDB Cluster

## Context

As MySQL environments shift towards High Availability (HA) architectures, MySQLTuner-perl must evolve to provide deep insights into clustered environments, specifically MySQL InnoDB Cluster (Group Replication).

## Proposed InnoDB Cluster Indicators

### 1. Group Replication Topology & Role Audit

* **Metric**: `performance_schema.replication_group_members`.
* **Logic**:
  * Audit `MEMBER_STATE`: Alert if not `ONLINE` (e.g., `RECOVERING`, `OFFLINE`, `ERROR`, `UNREACHABLE`).
  * Verify `MEMBER_ROLE`: Ensure only one `PRIMARY` exists if `group_replication_single_primary_mode` is `ON`.
  * Compare `MEMBER_VERSION`: Warn if members are running different MySQL versions.

### 2. Flow Control & Throttling Detection

* **Metric**: `performance_schema.replication_group_member_stats`.
* **Target Variables**: `group_replication_flow_control_applier_threshold`, `group_replication_flow_control_certifier_threshold`.
* **Logic**:
  * Track `COUNT_TRANSACTIONS_IN_QUEUE` (Certification queue).
  * Track `COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE` (Applier queue).
  * **Recommendation**: If `COUNT_TRANSACTIONS_IN_QUEUE > certifier_threshold`, suggest increasing `group_replication_flow_control_period` or reviewing write heavy-load.

### 3. Certification Conflict Monitoring

* **Metric**: `performance_schema.replication_group_member_stats` (`transactions_committed_all_members` vs `transactions_local_rollback`).
* **Logic**:
  * Calculate rollback ratio: `transactions_local_rollback / (transactions_committed_all_members + transactions_local_rollback)`.
  * **Threshold**: If > 5%, alert on high optimistic locking conflicts (common in Multi-Primary).

### 4. Distributed Performance Lag & MTR

* **Metric**: `performance_schema.replication_applier_status_by_worker`.
* **Logic**:
  * Audit `slave_parallel_workers` utilization for Multi-Threaded Replication (MTR).
  * Compare `Transactions_Behind` across nodes to identify the "Slowest Member" slowing down the whole cluster via Flow Control.

### 5. Quorum & Resilience Safeguarding

* **Metric**: `performance_schema.replication_group_communication_information`.
* **Check**: `group_replication_unreachable_majority_timeout`.
* **Check**: `group_replication_message_cache_size` (Default 1GB) vs available RAM to prevent OOM in high-traffic clusters.

### 6. MySQL Router Connectivity (Experimental)

* **Logic**: Verify if the user connecting to the instance is identified as coming from a known MySQL Router host.
* **Indicator**: Check `performance_schema.threads` or `processlist` for specific router metadata if available.

## Expected Value

* **Resilience**: Proactive detection of cluster partition risks.
* **Performance**: Identifying the "bottleneck node" that triggers cluster-wide flow control.
* **Observability**: Bringing enterprise-grade HA monitoring to a single-file script.
