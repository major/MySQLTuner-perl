---
test_file: tests/unit_galera_enhanced.t
---
# Specification: Roadmap Phase VIII - Galera Cluster 4 & PXC 8.0 Mastery

## Goal

Provide advanced Galera 4 and Percona XtraDB Cluster (PXC) 8.0 cluster health diagnostics, flow control analysis, and wsrep variable checks.

## Context

Galera Cluster 4 (MariaDB 10.4+) and Percona XtraDB Cluster 8.0 have introduced significant enhancements such as streaming replication and improved flow control. Phase VIII focuses on deep observability of these modern synchronous clusters.

## Proposed Galera Cluster Indicators

### 1. Streaming Replication Monitor

* **Metric**: `wsrep_streaming_log_writes` and `wsrep_streaming_log_reads`.
* **Indicator**: Detect if large transactions are triggering streaming replication.
* **Recommendation**: Review `wsrep_trx_fragment_size` and ensure storage can handle the additional I/O load.

### 2. Gcache Efficiency & IST Safeguarding

* **Metric**: `gcache.size` vs current write load.
* **Indicator**: Predict if a node re-joining after downtime will require a full SST or can suffice with IST.
* **Recommendation**: Increase `gcache.size` to cover typical maintenance windows.

### 3. Certification Conflict & Abort Analysis

* **Metric**: `wsrep_local_bf_aborts` and `wsrep_local_cert_failures`.
* **Logic**: Calculate the ratio of aborted transactions.
* **Recommendation**: Identify "hotspot" tables and suggest partitioning or app-level sharding.

### 4. Advanced Flow Control Observability

* **Metric**: `wsrep_flow_control_paused`, `wsrep_flow_control_sent`, and `wsrep_flow_control_recv`.
* **Flow Control Parameters**: Inspect `wsrep_provider_options` for `gcs.fc_limit` (default 64) and `gcs.fc_factor` (default 0.8). Low values cause aggressive throttling on moderate write bursts.
* **Logic**: Identify which specific node is triggering flow control across the cluster ("Victim" vs "Culprit" detection).
* **Recommendation**: Increase `gcs.fc_limit` and check disk latency on nodes with high `fc_sent`.

### 5. Non-PK Certification & Split-Brain Safeguards

* **Primary Key Enforcement**: Warn if tables lack primary keys and `wsrep_certify_non_pk = OFF`, as writes cannot be safely verified in multi-writer topologies.
* **Even Cluster Size Warning**: Warn if cluster node count is an even number (e.g., 2 or 4 nodes) without `garbd` (Galera Arbitrator Daemon), exposing the cluster to split-brain partition failures.

### 6. Group Communication Latency

* **Metric**: `wsrep_evs_repl_latency` (min/avg/max/stddev).
* **Indicator**: Detect network jitter between nodes.
* **Recommendation**: Optimize network path or review Cloud availability zone placement.

### 6. Applier Concurrency Tuning

* **Metric**: `wsrep_cert_deps_distance` vs `wsrep_slave_threads`.
* **Indicator**: Verify if the number of applier threads matches the potential parallelism of the workload.

## Expected Value

* **Clustering Stability**: Avoiding expensive SST operations.
* **Performance**: Reducing the impact of flow control on write throughput.
* **Diagnostics**: Faster root cause analysis for "hanging" clusters.

## Verification

- Validated via `tests/unit_galera_enhanced.t` and `tests/unit_galera_pxc.t`.
- Confirms wsrep cluster status parsing and flow control conflict reporting.
