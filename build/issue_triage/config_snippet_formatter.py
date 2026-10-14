"""
Actionable Configuration Snippet Formatter for my.cnf and mariadb.cnf
"""

from __future__ import annotations

from typing import List, Dict, Any, Optional, Tuple
from build.issue_triage.models import DiagnosticFinding


class ConfigSnippetFormatter:
    CATEGORY_ORDER = {
        "innodb_buffer_pool_size": 10,
        "innodb_buffer_pool_instances": 11,
        "innodb_redo_log_capacity": 12,
        "innodb_log_file_size": 13,
        "innodb_io_capacity": 14,
        "innodb_io_capacity_max": 15,
        "max_connections": 20,
        "thread_cache_size": 21,
        "table_open_cache": 30,
        "table_open_cache_instances": 31,
        "table_definition_cache": 32,
        "open_files_limit": 33,
        "tmp_table_size": 40,
        "max_heap_table_size": 41,
        "require_secure_transport": 50,
        "default_authentication_plugin": 51,
        "slow_query_log": 60,
        "long_query_time": 61,
    }

    @classmethod
    def format_cnf_block(
        cls,
        findings: List[DiagnosticFinding],
        is_mariadb: bool = False,
    ) -> str:
        aggregated_directives: Dict[str, Tuple[str, str]] = {}

        for f in findings:
            for var_name, var_val in f.suggested_cnf_directives.items():
                if var_name not in aggregated_directives:
                    aggregated_directives[var_name] = (var_val, f.title)

        if not aggregated_directives:
            return ""

        sorted_vars = sorted(
            aggregated_directives.keys(),
            key=lambda k: cls.CATEGORY_ORDER.get(k, 99),
        )

        target_file = "/etc/mysql/mariadb.conf.d/50-server.cnf" if is_mariadb else "/etc/mysql/mysql.conf.d/mysqld.cnf"

        lines = [
            f"# Suggested tuning configuration: {target_file}",
            "[mysqld]",
        ]

        for var in sorted_vars:
            val, reason = aggregated_directives[var]
            lines.append(f"# {reason}")
            lines.append(f"{var} = {val}\n")

        return "\n".join(lines)
