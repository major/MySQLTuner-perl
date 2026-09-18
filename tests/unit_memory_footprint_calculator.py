"""
Unit tests for build.issue_triage.memory_footprint_calculator
"""

import unittest
from build.issue_triage.memory_footprint_calculator import MemoryFootprintCalculator


class TestMemoryFootprintCalculator(unittest.TestCase):
    def test_safe_memory_allocation(self):
        vars_ = {
            "innodb_buffer_pool_size": 8 * 1024 ** 3,  # 8GB
            "max_connections": 100,
        }
        res = MemoryFootprintCalculator.calculate(
            vars_=vars_,
            status={"max_used_connections": 50},
            physical_ram_bytes=32 * 1024 ** 3,  # 32GB RAM
        )
        self.assertEqual(res.oom_risk_level, "SAFE")
        self.assertLess(res.max_memory_pct_of_ram, 50.0)

    def test_critical_oom_risk(self):
        vars_ = {
            "innodb_buffer_pool_size": 28 * 1024 ** 3,  # 28GB on 32GB
            "max_connections": 1000,
            "join_buffer_size": 8 * 1024 ** 2,  # 8MB per thread!
        }
        res = MemoryFootprintCalculator.calculate(
            vars_=vars_,
            status={"max_used_connections": 200},
            physical_ram_bytes=32 * 1024 ** 3,  # 32GB
        )
        self.assertEqual(res.oom_risk_level, "CRITICAL")
        self.assertGreater(res.max_memory_pct_of_ram, 100.0)

        finding = MemoryFootprintCalculator.generate_diagnostic_finding(res)
        self.assertIsNotNone(finding)
        self.assertEqual(finding.severity, "CRITICAL")


if __name__ == "__main__":
    unittest.main()
