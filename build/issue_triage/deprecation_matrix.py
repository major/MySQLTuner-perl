"""
Database Variable Lifecycle and Deprecation Matrix
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Dict, Tuple, List, Any


@dataclass
class VariableLifecycle:
    var_name: str
    introduced: Tuple[int, int]
    deprecated_in: Optional[Tuple[int, int]]
    removed_in: Optional[Tuple[int, int]]
    replacement_var: Optional[str]
    notes: str
    doc_url: str


class DeprecationMatrix:
    MYSQL_MATRIX: Dict[str, VariableLifecycle] = {
        "query_cache_type": VariableLifecycle(
            var_name="query_cache_type",
            introduced=(4, 0),
            deprecated_in=(5, 7),
            removed_in=(8, 0),
            replacement_var=None,
            notes="Query Cache was removed in MySQL 8.0. Use application-level caching (Redis/Memcached) or ProxySQL query caching.",
            doc_url="https://dev.mysql.com/doc/refman/8.0/en/added-deprecated-removed.html",
        ),
        "query_cache_size": VariableLifecycle(
            var_name="query_cache_size",
            introduced=(4, 0),
            deprecated_in=(5, 7),
            removed_in=(8, 0),
            replacement_var=None,
            notes="Query Cache was removed in MySQL 8.0.",
            doc_url="https://dev.mysql.com/doc/refman/8.0/en/added-deprecated-removed.html",
        ),
        "innodb_log_file_size": VariableLifecycle(
            var_name="innodb_log_file_size",
            introduced=(4, 0),
            deprecated_in=(8, 0),
            removed_in=None,
            replacement_var="innodb_redo_log_capacity",
            notes="In MySQL 8.0.30+ and 8.4 LTS, dynamic redo log sizing via innodb_redo_log_capacity is preferred.",
            doc_url="https://dev.mysql.com/doc/refman/8.4/en/innodb-redo-log.html",
        ),
        "innodb_log_files_in_group": VariableLifecycle(
            var_name="innodb_log_files_in_group",
            introduced=(4, 0),
            deprecated_in=(8, 0),
            removed_in=None,
            replacement_var="innodb_redo_log_capacity",
            notes="In MySQL 8.0.30+ and 8.4 LTS, dynamic redo log sizing via innodb_redo_log_capacity is preferred.",
            doc_url="https://dev.mysql.com/doc/refman/8.4/en/innodb-redo-log.html",
        ),
        "table_cache": VariableLifecycle(
            var_name="table_cache",
            introduced=(3, 23),
            deprecated_in=(5, 1),
            removed_in=(5, 5),
            replacement_var="table_open_cache",
            notes="Renamed to table_open_cache in MySQL 5.1.3+.",
            doc_url="https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_table_open_cache",
        ),
        "tx_isolation": VariableLifecycle(
            var_name="tx_isolation",
            introduced=(4, 0),
            deprecated_in=(5, 7),
            removed_in=(8, 0),
            replacement_var="transaction_isolation",
            notes="Renamed to transaction_isolation in MySQL 5.7.20 and removed in 8.0.",
            doc_url="https://dev.mysql.com/doc/refman/8.0/en/server-system-variables.html#sysvar_transaction_isolation",
        ),
        "expire_logs_days": VariableLifecycle(
            var_name="expire_logs_days",
            introduced=(4, 1),
            deprecated_in=(8, 0),
            removed_in=(9, 0),
            replacement_var="binlog_expire_logs_seconds",
            notes="Use binlog_expire_logs_seconds in MySQL 8.0+ / 8.4 LTS.",
            doc_url="https://dev.mysql.com/doc/refman/8.4/en/replication-options-binary-log.html#sysvar_binlog_expire_logs_seconds",
        ),
    }

    MARIADB_MATRIX: Dict[str, VariableLifecycle] = {
        "table_cache": VariableLifecycle(
            var_name="table_cache",
            introduced=(5, 1),
            deprecated_in=(10, 0),
            removed_in=(10, 1),
            replacement_var="table_open_cache",
            notes="Renamed to table_open_cache.",
            doc_url="https://mariadb.com/kb/en/server-system-variables/#table_open_cache",
        ),
        "tx_isolation": VariableLifecycle(
            var_name="tx_isolation",
            introduced=(5, 1),
            deprecated_in=(10, 3),
            removed_in=(11, 0),
            replacement_var="transaction_isolation",
            notes="Use transaction_isolation.",
            doc_url="https://mariadb.com/kb/en/server-system-variables/#transaction_isolation",
        ),
    }

    @classmethod
    def check_variable(
        cls, is_mariadb: bool, major: int, minor: int, var_name: str
    ) -> Optional[Dict[str, Any]]:
        var_clean = var_name.lower().strip()
        matrix = cls.MARIADB_MATRIX if is_mariadb else cls.MYSQL_MATRIX
        lifecycle = matrix.get(var_clean)
        if not lifecycle:
            return None

        current_ver = (major, minor)
        status = "CURRENT"
        if lifecycle.removed_in and current_ver >= lifecycle.removed_in:
            status = "REMOVED"
        elif lifecycle.deprecated_in and current_ver >= lifecycle.deprecated_in:
            status = "DEPRECATED"

        if status in ["DEPRECATED", "REMOVED"]:
            return {
                "var_name": var_clean,
                "status": status,
                "replacement_var": lifecycle.replacement_var,
                "notes": lifecycle.notes,
                "doc_url": lifecycle.doc_url,
            }
        return None
