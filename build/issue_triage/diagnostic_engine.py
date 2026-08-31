"""
Unified Diagnostic Engine Orchestrator for MySQLTuner Issue Triage
"""

from __future__ import annotations

import logging
from typing import List, Dict, Any, Optional
from build.issue_triage.models import (
    GitHubIssueRecord,
    DiagnosticFinding,
    ExtractedMetrics,
    TriageStatus,
    IssueCategory,
    IssueAuthorType,
)
from build.issue_triage.db_taxonomy import DatabaseTaxonomyResolver
from build.issue_triage.mysqltuner_output_parser import MySQLTunerOutputParser
from build.issue_triage.error_log_parser import ErrorLogParser
from build.issue_triage.variable_extractor import VariableExtractor
from build.issue_triage.sql_modeling_parser import SQLModelingParser
from build.issue_triage.infra_metric_parser import InfraMetricParser
from build.issue_triage.stack_trace_analyzer import StackTraceAnalyzer
from build.issue_triage.deprecation_matrix import DeprecationMatrix
from build.issue_triage.rule_evaluator import RuleEvaluator
from build.issue_triage.innodb_expert_diagnostics import InnoDBExpertDiagnostics
from build.issue_triage.memory_footprint_calculator import MemoryFootprintCalculator
from build.issue_triage.table_cache_diagnostics import TableCacheDiagnostics
from build.issue_triage.ha_replication_diagnostics import HAReplicationDiagnostics
from build.issue_triage.security_auth_diagnostics import SecurityAuthDiagnostics
from build.issue_triage.pfs_query_diagnostics import PFSQueryDiagnostics

logger = logging.getLogger("issue_triage.diagnostic")


class DiagnosticEngine:
    def __init__(self, mysqltuner_script_path: Optional[str] = None):
        self.stack_analyzer = StackTraceAnalyzer(mysqltuner_script_path)

    def analyze_issue(self, issue: GitHubIssueRecord) -> GitHubIssueRecord:
        full_text = f"{issue.title}\n{issue.body}\n" + "\n".join(c.body for c in issue.comments)
        
        # 1. Parse MySQLTuner report if present
        mt_report = MySQLTunerOutputParser.parse_report_text(full_text)
        
        # 2. Extract DB version & taxonomy
        raw_ver = mt_report.db_info.raw_version if mt_report.db_info else ""
        db_info = DatabaseTaxonomyResolver.resolve(raw_ver, context_text=full_text)
        
        # 3. Extract variables and status metrics
        vars_dict = VariableExtractor.extract_from_text(full_text)
        
        # Merge adjust variables from MT report
        for k, v in mt_report.adjust_variables.items():
            if k not in vars_dict:
                parsed_val = VariableExtractor._smart_cast(v.lstrip(">=< "))
                vars_dict[k] = parsed_val

        # 4. Extract infra metrics
        infra = InfraMetricParser.parse_infra_text(full_text)

        # 5. Extract SQL modeling findings
        sql_anomalies = SQLModelingParser.parse_sql_text(full_text)

        # 6. Extract Error Log events
        error_events = ErrorLogParser.parse_log_excerpt(full_text)

        # 7. Extract Stack traces / Perl warnings
        stack_findings = self.stack_analyzer.analyze_text(full_text)

        # Populate extracted metrics
        issue.extracted_metrics = ExtractedMetrics(
            db_engine=db_info.engine_type,
            db_version_raw=db_info.raw_version,
            db_version_normalized=db_info.normalized_version,
            variables=vars_dict,
            status_metrics={},
            system_metrics={
                "physical_ram_bytes": infra.total_ram_bytes,
                "is_container": infra.is_container,
                "cpu_cores": infra.cpu_cores,
            },
            sql_snippets=[a.description for a in sql_anomalies],
            error_log_excerpts=[e.raw_message for e in error_events],
            stack_traces=[s.raw_message for s in stack_findings],
        )

        findings: List[DiagnosticFinding] = []

        # Diagnostic 1: Deprecated variables
        for var_name in vars_dict.keys():
            dep = DeprecationMatrix.check_variable(
                is_mariadb=db_info.is_mariadb,
                major=db_info.major,
                minor=db_info.minor,
                var_name=var_name,
            )
            if dep:
                findings.append(
                    DiagnosticFinding(
                        rule_id=f"DEP_VAR_{var_name.upper()}",
                        title=f"Variable '{var_name}' is {dep['status']} in {db_info.engine_type.value} {db_info.normalized_version}",
                        severity="WARN" if dep["status"] == "DEPRECATED" else "BAD",
                        root_cause=dep["notes"],
                        confidence_score=0.99,
                        official_doc_url=dep["doc_url"],
                        recommendation=f"Replace '{var_name}' with '{dep['replacement_var']}'" if dep["replacement_var"] else f"Remove '{var_name}' from configuration.",
                        suggested_cnf_directives={dep["replacement_var"]: "configured"} if dep["replacement_var"] else {},
                    )
                )

        # Diagnostic 2: Memory Footprint & OOM
        mem_res = MemoryFootprintCalculator.calculate(
            vars_=vars_dict,
            status={},
            physical_ram_bytes=infra.total_ram_bytes,
            cgroup_ram_bytes=infra.cgroup_memory_limit_bytes,
        )
        mem_finding = MemoryFootprintCalculator.generate_diagnostic_finding(mem_res)
        if mem_finding:
            findings.append(mem_finding)

        # Diagnostic 3: InnoDB Buffer Pool & Redo Log
        bp_size = vars_dict.get("innodb_buffer_pool_size")
        bp_inst = vars_dict.get("innodb_buffer_pool_instances")
        if bp_size and bp_inst:
            ib_finding = InnoDBExpertDiagnostics.diagnose_buffer_pool_instances(
                int(bp_size), int(bp_inst), cpu_cores=infra.cpu_cores
            )
            if ib_finding:
                findings.append(ib_finding)

        # Diagnostic 4: Table Cache & Descriptors
        tc_size = vars_dict.get("table_open_cache")
        max_conns = vars_dict.get("max_connections", 151)
        if tc_size:
            tc_findings = TableCacheDiagnostics.diagnose_table_cache_and_descriptors(
                table_open_cache=int(tc_size),
                table_definition_cache=vars_dict.get("table_definition_cache"),
                open_files_limit=vars_dict.get("open_files_limit"),
                max_connections=int(max_conns),
                table_open_cache_instances=vars_dict.get("table_open_cache_instances"),
            )
            findings.extend(tc_findings)

        # Diagnostic 5: HA & Replication
        ha_findings = HAReplicationDiagnostics.diagnose_galera({}, vars_dict)
        findings.extend(ha_findings)

        # Diagnostic 6: Security & Authentication
        sec_findings = SecurityAuthDiagnostics.diagnose_security(
            vars_dict, {}, major_version=db_info.major, minor_version=db_info.minor, is_mariadb=db_info.is_mariadb
        )
        findings.extend(sec_findings)

        # Diagnostic 7: Performance Schema
        pfs_findings = PFSQueryDiagnostics.diagnose_pfs_and_queries(
            vars_dict, {}, physical_ram_bytes=infra.total_ram_bytes
        )
        findings.extend(pfs_findings)

        issue.findings = findings

        # Assign Triage Status
        if issue.author_type == IssueAuthorType.MAINTAINER:
            issue.triage_status = TriageStatus.MAINTAINER_HOLD
        elif any(f.severity in ["CRITICAL", "BAD", "WARN"] for f in findings):
            issue.triage_status = TriageStatus.DIAGNOSED
        else:
            issue.triage_status = TriageStatus.VERIFIED_ON_MASTER

        return issue
