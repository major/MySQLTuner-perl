"""
Unit tests for build.issue_triage.pfs_query_diagnostics
"""

import unittest
from build.issue_triage.pfs_query_diagnostics import PFSQueryDiagnostics


class TestPFSQueryDiagnostics(unittest.TestCase):
    def test_pfs_on_low_memory_instance(self):
        vars_ = {"performance_schema": 1}
        status = {"slow_queries": 2, "questions": 1000}
        findings = PFSQueryDiagnostics.diagnose_pfs_and_queries(
            vars_, status, physical_ram_bytes=1024 * 1024 ** 2  # 1GB RAM
        )
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].rule_id, "PFS_MEM_OVERHEAD_01")
        self.assertEqual(findings[0].severity, "WARN")

    def test_high_slow_query_ratio(self):
        vars_ = {"performance_schema": 1}
        status = {"slow_queries": 150, "questions": 1000}  # 15% slow queries
        findings = PFSQueryDiagnostics.diagnose_pfs_and_queries(
            vars_, status, physical_ram_bytes=16 * 1024 ** 3
        )
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].rule_id, "QUERY_SLOW_RATIO_01")
        self.assertEqual(findings[0].severity, "BAD")


if __name__ == "__main__":
    unittest.main()
