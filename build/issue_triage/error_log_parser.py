"""
Semantic MySQL & MariaDB Error Log Parser and Classifier
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from enum import Enum
from typing import List, Dict, Optional, Any


class ErrorEventType(str, Enum):
    INNODB_DEADLOCK = "innodb_deadlock"
    INNODB_CORRUPTION = "innodb_corruption"
    INNODB_REDO_FULL = "innodb_redo_full"
    MEMORY_OOM = "memory_oom"
    TABLE_CACHE_SATURATION = "table_cache_saturation"
    AUTHENTICATION_FAILURE = "authentication_failure"
    WSREP_DESYNC = "wsrep_desync"
    REPLICATION_BREAK = "replication_break"
    DEPRECATION_WARNING = "deprecation_warning"
    UNKNOWN_ERROR = "unknown_error"


@dataclass
class ParsedErrorEvent:
    event_type: ErrorEventType
    severity: str  # 'ERROR', 'WARNING', 'NOTE'
    timestamp_raw: Optional[str]
    error_code: Optional[str]  # e.g., 'MY-011925' or '1062'
    raw_message: str
    suggested_action: str


class ErrorLogParser:
    PATTERNS = [
        (
            re.compile(r"(?:Deadlock found when trying to get lock|Lock wait timeout exceeded)", re.IGNORECASE),
            ErrorEventType.INNODB_DEADLOCK,
            "HIGH",
            "Review query execution plans, transactions isolation level, and consider reducing transaction lock duration.",
        ),
        (
            re.compile(r"(?:InnoDB: Page [0-9]+ in space [0-9]+ seems to be corrupted|checksum mismatch|Assertion failure:.*innodb)", re.IGNORECASE),
            ErrorEventType.INNODB_CORRUPTION,
            "CRITICAL",
            "Immediate backup and recovery required. Investigate hardware/storage integrity and innodb_force_recovery options.",
        ),
        (
            re.compile(r"(?:Log file .* is full|Cannot allocate space for log files|InnoDB: Redo log is full)", re.IGNORECASE),
            ErrorEventType.INNODB_REDO_FULL,
            "CRITICAL",
            "Increase innodb_redo_log_capacity (MySQL 8.0.30+) or innodb_log_file_size / innodb_log_files_in_group (MariaDB/older MySQL).",
        ),
        (
            re.compile(r"(?:Out of memory \(Needed [0-9]+ bytes\)|Cannot allocate memory for the buffer pool|Cannot allocate [0-9]+ bytes in file)", re.IGNORECASE),
            ErrorEventType.MEMORY_OOM,
            "CRITICAL",
            "Reduce innodb_buffer_pool_size or per-thread memory (max_connections, join_buffer_size, sort_buffer_size).",
        ),
        (
            re.compile(r"(?:Too many open files|Can't open file: .* \(errno: 24|table_open_cache .* reached limit)", re.IGNORECASE),
            ErrorEventType.TABLE_CACHE_SATURATION,
            "HIGH",
            "Increase open_files_limit in systemd/system limits and adjust table_open_cache.",
        ),
        (
            re.compile(r"(?:Access denied for user|Plugin 'caching_sha2_password' is not loaded|authentication handshake failed)", re.IGNORECASE),
            ErrorEventType.AUTHENTICATION_FAILURE,
            "HIGH",
            "Verify user credentials, host privileges, and authentication plugin compatibility with client driver.",
        ),
        (
            re.compile(r"(?:WSREP: Node .* state is non-primary|WSREP: Failed to prepare for SST|Galera desync)", re.IGNORECASE),
            ErrorEventType.WSREP_DESYNC,
            "CRITICAL",
            "Inspect Galera cluster state, wsrep_cluster_address, and network latency between cluster nodes.",
        ),
        (
            re.compile(r"(?:Slave I/O for channel .*: Fatal error|Slave SQL for channel .*: Error 'Duplicate entry'|Last_SQL_Error)", re.IGNORECASE),
            ErrorEventType.REPLICATION_BREAK,
            "CRITICAL",
            "Inspect GTID execution positions and replication channel error details.",
        ),
    ]

    TIMESTAMP_MY8_REGEX = re.compile(r"^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+Z)\s+([0-9]+)\s+\[([^\]]+)\]\s+\[([^\]]+)\]\s*(.*)$")
    TIMESTAMP_GEN_REGEX = re.compile(r"^([0-9]{4}-[0-9]{2}-[0-9]{2}[\sT][0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?(?:Z)?)\s*(.*)$")

    @classmethod
    def parse_log_excerpt(cls, text: str) -> List[ParsedErrorEvent]:
        events: List[ParsedErrorEvent] = []
        if not text:
            return events

        for line in text.splitlines():
            line_str = line.strip()
            if not line_str:
                continue

            # Extract timestamp & error code if available
            timestamp = None
            err_code = None
            severity = "ERROR"

            m8 = cls.TIMESTAMP_MY8_REGEX.search(line_str)
            if m8:
                timestamp = m8.group(1)
                severity = m8.group(3)
                err_code = m8.group(4)
                content = m8.group(5)
            else:
                mg = cls.TIMESTAMP_GEN_REGEX.search(line_str)
                if mg:
                    timestamp = mg.group(1)
                    content = mg.group(2)
                else:
                    content = line_str

            # Check known error patterns
            for pattern, evt_type, sev, action in cls.PATTERNS:
                if pattern.search(content):
                    events.append(
                        ParsedErrorEvent(
                            event_type=evt_type,
                            severity=severity,
                            timestamp_raw=timestamp,
                            error_code=err_code,
                            raw_message=content,
                            suggested_action=action,
                        )
                    )
                    break

        return events
