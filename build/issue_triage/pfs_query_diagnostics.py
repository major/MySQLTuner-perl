"""
Performance Schema (PFS) and Query Efficiency Diagnostics Module
"""

from __future__ import annotations

from typing import Dict, Any, List, Optional
from build.issue_triage.models import DiagnosticFinding


class PFSQueryDiagnostics:
    @classmethod
    def diagnose_pfs_and_queries(
        cls,
        vars_: Dict[str, Any],
        status: Dict[str, Any],
        physical_ram_bytes: Optional[int] = None,
    ) -> List[DiagnosticFinding]:
        findings: List[DiagnosticFinding] = []

        # Check 1: Performance Schema on Small Instances
        pfs_enabled = vars_.get("performance_schema")
        if pfs_enabled == 1 or pfs_enabled == "ON":
            if physical_ram_bytes and physical_ram_bytes < (2 * 1024 ** 3):
                findings.append(
                    DiagnosticFinding(
                        rule_id="PFS_MEM_OVERHEAD_01",
                        title="Performance Schema Enabled on Low-Memory Instance (< 2GB RAM)",
                        severity="WARN",
                        root_cause=f"Physical RAM is {physical_ram_bytes / (1024**2):.0f}MB. Performance Schema memory allocation can consume 200-400MB of RAM.",
                        confidence_score=0.92,
                        official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/performance-schema-memory-model.html",
                        recommendation="Consider disabling performance_schema (performance_schema = OFF) or enabling only essential instruments.",
                        suggested_cnf_directives={"performance_schema": "OFF"},
                    )
                )
        elif pfs_enabled == 0 or pfs_enabled == "OFF":
            if physical_ram_bytes and physical_ram_bytes >= (4 * 1024 ** 3):
                findings.append(
                    DiagnosticFinding(
                        rule_id="PFS_DISABLED_01",
                        title="Performance Schema is Disabled on Production Instance",
                        severity="INFO",
                        root_cause="performance_schema = OFF prevents detailed execution latency and query profiling.",
                        confidence_score=0.90,
                        official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/performance-schema.html",
                        recommendation="Enable performance_schema for advanced bottleneck observability.",
                        suggested_cnf_directives={"performance_schema": "ON"},
                    )
                )

        # Check 2: Slow Queries Ratio
        slow_queries = status.get("slow_queries")
        questions = status.get("questions")
        if slow_queries is not None and questions is not None and questions > 100:
            slow_pct = (float(slow_queries) / float(questions)) * 100.0
            if slow_pct > 5.0:
                findings.append(
                    DiagnosticFinding(
                        rule_id="QUERY_SLOW_RATIO_01",
                        title=f"High Percentage of Slow Queries ({slow_pct:.2f}%)",
                        severity="BAD",
                        root_cause=f"{slow_queries} out of {questions} queries took longer than long_query_time to execute (> 5%).",
                        confidence_score=0.95,
                        official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/slow-query-log.html",
                        recommendation="Enable slow query log with log_output = FILE,TABLE and analyze statements via mysqldumpslow or pt-query-digest.",
                        suggested_cnf_directives={
                            "slow_query_log": "ON",
                            "long_query_time": "2",
                        },
                    )
                )

        return findings
