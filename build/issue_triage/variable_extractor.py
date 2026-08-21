"""
Database Variable and Status Metric Extractor & Normalizer
"""

from __future__ import annotations

import re
from typing import Dict, Any, Optional, Tuple


class VariableExtractor:
    SIZE_UNIT_REGEX = re.compile(r"^([0-9.]+)\s*([KMGTPE]?i?B?)$", re.IGNORECASE)
    
    UNIT_MULTIPLIERS = {
        "": 1,
        "b": 1,
        "k": 1024,
        "kb": 1024,
        "kib": 1024,
        "m": 1024 ** 2,
        "mb": 1024 ** 2,
        "mib": 1024 ** 2,
        "g": 1024 ** 3,
        "gb": 1024 ** 3,
        "gib": 1024 ** 3,
        "t": 1024 ** 4,
        "tb": 1024 ** 4,
        "tib": 1024 ** 4,
    }

    BOOLEAN_MAP = {
        "on": 1,
        "true": 1,
        "yes": 1,
        "1": 1,
        "off": 0,
        "false": 0,
        "no": 0,
        "0": 0,
    }

    KNOWN_VARIABLES = {
        # InnoDB
        "innodb_buffer_pool_size", "innodb_buffer_pool_instances", "innodb_log_file_size",
        "innodb_log_files_in_group", "innodb_redo_log_capacity", "innodb_flush_log_at_trx_commit",
        "innodb_file_per_table", "innodb_io_capacity", "innodb_io_capacity_max", "innodb_flush_method",
        # Connections & Buffers
        "max_connections", "max_user_connections", "thread_cache_size", "wait_timeout",
        "interactive_timeout", "join_buffer_size", "sort_buffer_size", "read_buffer_size",
        "read_rnd_buffer_size", "tmp_table_size", "max_heap_table_size",
        # Table cache & descriptors
        "table_open_cache", "table_open_cache_instances", "table_definition_cache",
        "open_files_limit",
        # Replication & HA
        "server_id", "binlog_format", "sync_binlog", "gtid_mode", "enforce_gtid_consistency",
        "wsrep_on", "wsrep_cluster_name", "wsrep_provider",
        # Query Cache (legacy)
        "query_cache_type", "query_cache_size", "query_cache_limit",
    }

    @classmethod
    def parse_size_to_bytes(cls, value_str: str) -> Optional[int]:
        if value_str is None:
            return None
        value_str = str(value_str).strip()
        if value_str.isdigit():
            return int(value_str)

        m = cls.SIZE_UNIT_REGEX.match(value_str)
        if m:
            num = float(m.group(1))
            unit = m.group(2).lower()
            multiplier = cls.UNIT_MULTIPLIERS.get(unit, 1)
            return int(num * multiplier)
        return None

    @classmethod
    def normalize_boolean(cls, value_str: str) -> Optional[int]:
        if value_str is None:
            return None
        val_clean = str(value_str).strip().lower()
        return cls.BOOLEAN_MAP.get(val_clean)

    @classmethod
    def extract_from_text(cls, text: str) -> Dict[str, Any]:
        extracted: Dict[str, Any] = {}
        if not text:
            return extracted

        # Pattern 1: Table format | variable_name | value |
        for m in re.finditer(r"\|\s*([a-zA-Z0-9_]{3,64})\s*\|\s*([^|\r\n]+)\s*\|", text):
            var_name = m.group(1).lower()
            val_raw = m.group(2).strip()
            extracted[var_name] = cls._smart_cast(val_raw)

        # Pattern 2: Key = Value or Key: Value
        for m in re.finditer(r"^\s*([a-zA-Z0-9_]{3,64})\s*[:=]\s*([^\r\n#;]+)", text, re.MULTILINE):
            var_name = m.group(1).lower()
            val_raw = m.group(2).strip().strip("'\"")
            if var_name not in extracted:
                extracted[var_name] = cls._smart_cast(val_raw)

        return extracted

    @classmethod
    def _smart_cast(cls, raw_val: str) -> Any:
        # Check boolean
        b = cls.normalize_boolean(raw_val)
        if b is not None and raw_val.lower() in ["on", "off", "true", "false", "yes", "no"]:
            return b

        # Check integer
        if raw_val.isdigit():
            return int(raw_val)

        # Check size (e.g. 16G)
        size_bytes = cls.parse_size_to_bytes(raw_val)
        if size_bytes is not None and any(u in raw_val.lower() for u in ["k", "m", "g", "t"]):
            return size_bytes

        return raw_val
