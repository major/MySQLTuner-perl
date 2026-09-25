"""
MySQLTuner Mathematical & Statistical Rule Evaluator
"""

from __future__ import annotations

from typing import Dict, List, Any, Optional
from build.issue_triage.models import DiagnosticFinding


class RuleEvaluator:
    @staticmethod
    def eval_buffer_pool_hit_rate(status: Dict[str, Any], vars_: Dict[str, Any]) -> Optional[DiagnosticFinding]:
        reads = status.get("innodb_buffer_pool_reads")
        requests = status.get("innodb_buffer_pool_read_requests")
        if reads is not None and requests is not None and requests > 0:
            hit_ratio = 100.0 - (float(reads) / float(requests) * 100.0)
            if hit_ratio < 95.0:
                return DiagnosticFinding(
                    rule_id="RULE_INNODB_HITRATE_01",
                    title="InnoDB Buffer Pool Hit Ratio is Low",
                    severity="BAD",
                    root_cause=f"Hit ratio is {hit_ratio:.2f}% (< 95.00%). Disk reads are occurring frequently.",
                    confidence_score=0.95,
                    official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/innodb-buffer-pool.html",
                    recommendation="Increase innodb_buffer_pool_size to allow working dataset caching in RAM.",
                    suggested_cnf_directives={"innodb_buffer_pool_size": "Increase by 25-50%"},
                )
            else:
                return DiagnosticFinding(
                    rule_id="RULE_INNODB_HITRATE_01",
                    title="InnoDB Buffer Pool Hit Ratio is Healthy",
                    severity="OK",
                    root_cause=f"Hit ratio is {hit_ratio:.2f}% (>= 95.00%).",
                    confidence_score=0.99,
                    official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/innodb-buffer-pool.html",
                    recommendation="Buffer pool sizing is optimal for the current active workload.",
                )
        return None

    @staticmethod
    def eval_tmp_tables_disk(status: Dict[str, Any], vars_: Dict[str, Any]) -> Optional[DiagnosticFinding]:
        tmp_disk = status.get("created_tmp_disk_tables")
        tmp_mem = status.get("created_tmp_tables")
        if tmp_disk is not None and tmp_mem is not None:
            total_tmp = tmp_disk + tmp_mem
            if total_tmp > 50:
                pct_disk = (float(tmp_disk) / float(total_tmp)) * 100.0
                if pct_disk > 25.0:
                    return DiagnosticFinding(
                        rule_id="RULE_TMP_TABLES_01",
                        title="High Percentage of Temporary Tables Created on Disk",
                        severity="BAD",
                        root_cause=f"{pct_disk:.2f}% of temporary tables are spilling to disk (> 25%).",
                        confidence_score=0.92,
                        official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/internal-temporary-tables.html",
                        recommendation="Increase tmp_table_size and max_heap_table_size, and optimize queries with GROUP BY / ORDER BY.",
                        suggested_cnf_directives={
                            "tmp_table_size": "64M",
                            "max_heap_table_size": "64M",
                        },
                    )
        return None

    @staticmethod
    def eval_table_open_cache(status: Dict[str, Any], vars_: Dict[str, Any]) -> Optional[DiagnosticFinding]:
        opened_tables = status.get("opened_tables")
        open_tables = status.get("open_tables")
        table_cache_size = vars_.get("table_open_cache")
        if opened_tables is not None and open_tables is not None and table_cache_size is not None:
            if opened_tables > 100 and (float(open_tables) / float(table_cache_size)) > 0.95:
                hit_rate = (float(open_tables) / float(opened_tables)) * 100.0
                if hit_rate < 50.0:
                    return DiagnosticFinding(
                        rule_id="RULE_TABLE_CACHE_01",
                        title="Table Open Cache Eviction Contention",
                        severity="WARN",
                        root_cause=f"Table cache is 95%+ full and hit rate is {hit_rate:.2f}%. Tables are being frequently closed and reopened.",
                        confidence_score=0.90,
                        official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/table-cache.html",
                        recommendation="Increase table_open_cache and verify open_files_limit accordingly.",
                        suggested_cnf_directives={"table_open_cache": str(int(table_cache_size * 1.5))},
                    )
        return None
