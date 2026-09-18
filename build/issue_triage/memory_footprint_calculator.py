"""
Database Memory Footprint & OOM Risk Calculator
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Any, Optional
from build.issue_triage.models import DiagnosticFinding


@dataclass
class MemoryCalculationResult:
    global_buffers_bytes: int
    per_thread_buffers_bytes: int
    max_connections: int
    max_used_connections: int
    total_max_memory_bytes: int
    total_peak_memory_bytes: int
    physical_ram_bytes: Optional[int]
    max_memory_pct_of_ram: Optional[float]
    peak_memory_pct_of_ram: Optional[float]
    oom_risk_level: str  # 'SAFE', 'MODERATE', 'HIGH', 'CRITICAL'


class MemoryFootprintCalculator:
    DEFAULT_THREAD_STACK = 262144        # 256K
    DEFAULT_NET_BUFFER = 16384           # 16K
    DEFAULT_READ_BUFFER = 131072         # 128K
    DEFAULT_READ_RND_BUFFER = 262144     # 256K
    DEFAULT_SORT_BUFFER = 262144         # 256K
    DEFAULT_JOIN_BUFFER = 262144         # 256K
    DEFAULT_BINLOG_CACHE = 32768         # 32K

    @classmethod
    def calculate(
        cls,
        vars_: Dict[str, Any],
        status: Dict[str, Any],
        physical_ram_bytes: Optional[int] = None,
        cgroup_ram_bytes: Optional[int] = None,
    ) -> MemoryCalculationResult:
        # Effective RAM limit is min(physical_ram, cgroup_ram)
        effective_ram = physical_ram_bytes
        if cgroup_ram_bytes is not None:
            if effective_ram is None or cgroup_ram_bytes < effective_ram:
                effective_ram = cgroup_ram_bytes

        # Global buffers
        ib_pool = int(vars_.get("innodb_buffer_pool_size") or 134217728)
        ib_log = int(vars_.get("innodb_log_buffer_size") or 16777216)
        key_buf = int(vars_.get("key_buffer_size") or 8388608)
        qc_size = int(vars_.get("query_cache_size") or 0)
        aria_buf = int(vars_.get("aria_pagecache_buffer_size") or 0)

        global_buffers = ib_pool + ib_log + key_buf + qc_size + aria_buf

        # Per thread buffers
        read_buf = int(vars_.get("read_buffer_size") or cls.DEFAULT_READ_BUFFER)
        read_rnd_buf = int(vars_.get("read_rnd_buffer_size") or cls.DEFAULT_READ_RND_BUFFER)
        sort_buf = int(vars_.get("sort_buffer_size") or cls.DEFAULT_SORT_BUFFER)
        join_buf = int(vars_.get("join_buffer_size") or cls.DEFAULT_JOIN_BUFFER)
        binlog_cache = int(vars_.get("binlog_cache_size") or cls.DEFAULT_BINLOG_CACHE)
        thread_stack = int(vars_.get("thread_stack") or cls.DEFAULT_THREAD_STACK)
        net_buf = int(vars_.get("net_buffer_length") or cls.DEFAULT_NET_BUFFER)

        per_thread_buffers = (
            read_buf + read_rnd_buf + sort_buf + join_buf + binlog_cache + thread_stack + net_buf
        )

        max_conns = int(vars_.get("max_connections") or 151)
        max_used_conns = int(status.get("max_used_connections") or 1)

        total_max_mem = global_buffers + (max_conns * per_thread_buffers)
        total_peak_mem = global_buffers + (max_used_conns * per_thread_buffers)

        max_pct = None
        peak_pct = None
        risk_level = "SAFE"

        if effective_ram and effective_ram > 0:
            max_pct = (total_max_mem / effective_ram) * 100.0
            peak_pct = (total_peak_mem / effective_ram) * 100.0

            if max_pct > 90.0:
                risk_level = "CRITICAL"
            elif max_pct > 80.0:
                risk_level = "HIGH"
            elif max_pct > 65.0:
                risk_level = "MODERATE"
            else:
                risk_level = "SAFE"

        return MemoryCalculationResult(
            global_buffers_bytes=global_buffers,
            per_thread_buffers_bytes=per_thread_buffers,
            max_connections=max_conns,
            max_used_connections=max_used_conns,
            total_max_memory_bytes=total_max_mem,
            total_peak_memory_bytes=total_peak_mem,
            physical_ram_bytes=effective_ram,
            max_memory_pct_of_ram=max_pct,
            peak_memory_pct_of_ram=peak_pct,
            oom_risk_level=risk_level,
        )

    @classmethod
    def generate_diagnostic_finding(cls, result: MemoryCalculationResult) -> Optional[DiagnosticFinding]:
        if result.max_memory_pct_of_ram is None:
            return None

        if result.oom_risk_level in ["HIGH", "CRITICAL"]:
            return DiagnosticFinding(
                rule_id="RULE_MEM_OOM_01",
                title=f"High Risk of Memory Exhaustion / OOM Killer ({result.max_memory_pct_of_ram:.1f}% of RAM)",
                severity="CRITICAL" if result.oom_risk_level == "CRITICAL" else "BAD",
                root_cause=f"Maximum potential memory allocation is {result.total_max_memory_bytes / (1024**3):.2f} GB ({result.max_memory_pct_of_ram:.1f}% of {result.physical_ram_bytes / (1024**3):.2f} GB RAM).",
                confidence_score=0.98,
                official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/memory-use.html",
                recommendation="Reduce max_connections or per-thread buffers (join_buffer_size, sort_buffer_size) to ensure total memory does not exceed 80% of RAM.",
                suggested_cnf_directives={
                    "max_connections": str(max(50, int(result.max_connections * 0.75))),
                    "join_buffer_size": "256K",
                    "sort_buffer_size": "512K",
                },
            )
        return None
