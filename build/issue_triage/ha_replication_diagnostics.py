"""
High Availability & Replication Diagnostics Module (Galera, PXC, Async, Semi-Sync)
"""

from __future__ import annotations

from typing import Dict, Any, List, Optional
from build.issue_triage.models import DiagnosticFinding


class HAReplicationDiagnostics:
    @classmethod
    def diagnose_galera(cls, status: Dict[str, Any], vars_: Dict[str, Any]) -> List[DiagnosticFinding]:
        findings: List[DiagnosticFinding] = []
        wsrep_on = vars_.get("wsrep_on") or status.get("wsrep_on")
        if wsrep_on != 1 and wsrep_on != "ON":
            return findings

        # Check 1: Cluster primary component
        cluster_status = str(status.get("wsrep_cluster_status") or "").strip().lower()
        if cluster_status and cluster_status != "primary":
            findings.append(
                DiagnosticFinding(
                    rule_id="GALERA_SPLIT_BRAIN_01",
                    title="Galera Node in Non-Primary Component",
                    severity="CRITICAL",
                    root_cause=f"wsrep_cluster_status is '{cluster_status}'. Node cannot process writes.",
                    confidence_score=0.99,
                    official_doc_url="https://galeracluster.com/library/documentation/node-states.html",
                    recommendation="Re-bootstrap or reconnect node to the primary Galera cluster component.",
                )
            )

        # Check 2: Node state
        state_comment = str(status.get("wsrep_local_state_comment") or "").strip().lower()
        if state_comment and state_comment != "synced":
            findings.append(
                DiagnosticFinding(
                    rule_id="GALERA_DESYNC_01",
                    title=f"Galera Node State is {state_comment.capitalize()}",
                    severity="WARN",
                    root_cause=f"Node state is '{state_comment}'. It is not fully synchronized to serve normal read/write traffic.",
                    confidence_score=0.95,
                    official_doc_url="https://galeracluster.com/library/documentation/node-states.html",
                    recommendation="Monitor state transfer (SST/IST) completion.",
                )
            )

        # Check 3: Flow control paused ratio
        fc_paused = status.get("wsrep_flow_control_paused")
        if fc_paused is not None:
            try:
                fc_float = float(fc_paused)
                if fc_float > 0.10:
                    findings.append(
                        DiagnosticFinding(
                            rule_id="GALERA_FLOW_CONTROL_01",
                            title="High Galera Flow Control Paused Ratio",
                            severity="BAD",
                            root_cause=f"wsrep_flow_control_paused is {fc_float * 100.0:.2f}% (> 10%). Slave queue is saturated.",
                            confidence_score=0.96,
                            official_doc_url="https://galeracluster.com/library/documentation/flow-control.html",
                            recommendation="Increase wsrep_slave_threads, optimize slow write queries, and inspect slowest node in cluster.",
                            suggested_cnf_directives={"wsrep_slave_threads": "8"},
                        )
                    )
            except ValueError:
                pass

        return findings

    @classmethod
    def diagnose_async_replication(cls, status: Dict[str, Any], vars_: Dict[str, Any]) -> List[DiagnosticFinding]:
        findings: List[DiagnosticFinding] = []
        
        io_running = status.get("slave_io_running") or status.get("replica_io_running")
        sql_running = status.get("slave_sql_running") or status.get("replica_sql_running")
        sec_behind = status.get("seconds_behind_master") or status.get("seconds_behind_source")

        if io_running is not None and str(io_running).lower() in ["no", "off", "0"]:
            findings.append(
                DiagnosticFinding(
                    rule_id="REPLI_IO_THREAD_01",
                    title="Replication I/O Thread is Stopped",
                    severity="CRITICAL",
                    root_cause="Replication I/O thread is not connected or stopped. No binary log events are being fetched.",
                    confidence_score=0.99,
                    official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/replication-troubleshooting.html",
                    recommendation="Run SHOW REPLICA STATUS to inspect Last_IO_Error and verify master connectivity.",
                )
            )

        if sql_running is not None and str(sql_running).lower() in ["no", "off", "0"]:
            findings.append(
                DiagnosticFinding(
                    rule_id="REPLI_SQL_THREAD_01",
                    title="Replication SQL Applier Thread is Stopped",
                    severity="CRITICAL",
                    root_cause="Replication SQL thread encountered an error and halted relay log execution.",
                    confidence_score=0.99,
                    official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/replication-troubleshooting.html",
                    recommendation="Inspect Last_SQL_Error in SHOW REPLICA STATUS and resolve conflicting transaction.",
                )
            )

        if sec_behind is not None:
            try:
                lag_sec = int(sec_behind)
                if lag_sec > 300:
                    findings.append(
                        DiagnosticFinding(
                            rule_id="REPLI_LAG_01",
                            title=f"High Replication Latency ({lag_sec}s)",
                            severity="BAD",
                            root_cause=f"Replica is {lag_sec} seconds behind primary (> 300s). Data is stale.",
                            confidence_score=0.95,
                            official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/replication-threads-monitor.html",
                            recommendation="Enable parallel replication applier workers (replica_parallel_workers).",
                            suggested_cnf_directives={
                                "replica_parallel_workers": "4",
                                "replica_parallel_type": "LOGICAL_CLOCK",
                            },
                        )
                    )
            except ValueError:
                pass

        return findings
