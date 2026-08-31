"""
InnoDB Buffer Pool and Redo Log Expert Diagnostics Module
"""

from __future__ import annotations

from typing import Dict, List, Any, Optional
from build.issue_triage.models import DiagnosticFinding


class InnoDBExpertDiagnostics:
    @classmethod
    def diagnose_buffer_pool_instances(
        cls, pool_size_bytes: int, instances: int, cpu_cores: Optional[int] = None
    ) -> Optional[DiagnosticFinding]:
        if pool_size_bytes <= 0 or instances <= 0:
            return None

        size_per_instance_gb = (pool_size_bytes / instances) / (1024 ** 3)

        if pool_size_bytes < (1024 ** 3) and instances > 1:
            return DiagnosticFinding(
                rule_id="INNODB_BP_INST_01",
                title="Excessive Buffer Pool Instances for Sub-1GB Pool",
                severity="WARN",
                root_cause=f"Buffer pool is {pool_size_bytes / (1024**2):.0f}MB (< 1GB) but configured with {instances} instances. Each instance overhead wastes memory.",
                confidence_score=0.98,
                official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/innodb-multiple-buffer-pools.html",
                recommendation="Set innodb_buffer_pool_instances = 1 for buffer pool sizes under 1GB.",
                suggested_cnf_directives={"innodb_buffer_pool_instances": "1"},
            )

        if size_per_instance_gb < 1.0 and pool_size_bytes >= (1024 ** 3):
            optimal_instances = max(1, int(pool_size_bytes / (1024 ** 3)))
            return DiagnosticFinding(
                rule_id="INNODB_BP_INST_02",
                title="Buffer Pool Instance Size Less Than 1GB",
                severity="WARN",
                root_cause=f"Each buffer pool instance is {size_per_instance_gb:.2f}GB (< 1GB). MySQL documentation recommends >= 1GB per instance.",
                confidence_score=0.95,
                official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/innodb-multiple-buffer-pools.html",
                recommendation=f"Set innodb_buffer_pool_instances = {optimal_instances}.",
                suggested_cnf_directives={"innodb_buffer_pool_instances": str(optimal_instances)},
            )

        return None

    @classmethod
    def diagnose_dirty_pages_ratio(
        cls, dirty_pages: int, total_pages: int
    ) -> Optional[DiagnosticFinding]:
        if total_pages <= 0:
            return None

        dirty_pct = (float(dirty_pages) / float(total_pages)) * 100.0
        if dirty_pct > 75.0:
            return DiagnosticFinding(
                rule_id="INNODB_DIRTY_PAGES_01",
                title="High InnoDB Dirty Pages Percentage",
                severity="BAD",
                root_cause=f"{dirty_pct:.2f}% of buffer pool pages are dirty (> 75%). Page flushing is lagging behind write workload.",
                confidence_score=0.94,
                official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/innodb-buffer-pool-flushing.html",
                recommendation="Increase innodb_io_capacity and innodb_io_capacity_max, or optimize storage I/O performance.",
                suggested_cnf_directives={
                    "innodb_io_capacity": "2000",
                    "innodb_io_capacity_max": "4000",
                },
            )
        return None
