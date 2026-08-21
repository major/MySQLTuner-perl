"""
Table Cache & File Descriptors Diagnostics Module
"""

from __future__ import annotations

from typing import Dict, Any, Optional, List
from build.issue_triage.models import DiagnosticFinding


class TableCacheDiagnostics:
    @classmethod
    def diagnose_table_cache_and_descriptors(
        cls,
        table_open_cache: int,
        table_definition_cache: Optional[int],
        open_files_limit: Optional[int],
        max_connections: int,
        table_open_cache_instances: Optional[int] = None,
    ) -> List[DiagnosticFinding]:
        findings: List[DiagnosticFinding] = []

        # Sizing open_files_limit
        # Official formula: max(10 + max_connections + (table_open_cache * 2), max_connections * 5)
        recommended_open_files = max(
            10 + max_connections + (table_open_cache * 2),
            max_connections * 5,
        )

        if open_files_limit is not None and open_files_limit < recommended_open_files:
            findings.append(
                DiagnosticFinding(
                    rule_id="TABLE_CACHE_FDS_01",
                    title="open_files_limit is Insufficient for Table Cache",
                    severity="BAD",
                    root_cause=f"open_files_limit is {open_files_limit} but required limit for table_open_cache ({table_open_cache}) and max_connections ({max_connections}) is >= {recommended_open_files}.",
                    confidence_score=0.96,
                    official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/table-cache.html",
                    recommendation=f"Increase open_files_limit in systemd and my.cnf to at least {recommended_open_files}.",
                    suggested_cnf_directives={"open_files_limit": str(recommended_open_files)},
                )
            )

        # Sizing table_open_cache_instances
        if table_open_cache >= 1000 and table_open_cache_instances == 1:
            findings.append(
                DiagnosticFinding(
                    rule_id="TABLE_CACHE_INST_01",
                    title="Single Table Cache Instance with Large Cache Size",
                    severity="WARN",
                    root_cause=f"table_open_cache is {table_open_cache} with only 1 instance. May cause mutex contention across threads.",
                    confidence_score=0.92,
                    official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html#sysvar_table_open_cache_instances",
                    recommendation="Set table_open_cache_instances = 16 to reduce lock contention.",
                    suggested_cnf_directives={"table_open_cache_instances": "16"},
                )
            )

        return findings
