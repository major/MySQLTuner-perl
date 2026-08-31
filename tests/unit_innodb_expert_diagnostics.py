"""
Unit tests for build.issue_triage.innodb_expert_diagnostics
"""

import unittest
from build.issue_triage.innodb_expert_diagnostics import InnoDBExpertDiagnostics


class TestInnoDBExpertDiagnostics(unittest.TestCase):
    def test_sub_1gb_pool_with_multiple_instances(self):
        finding = InnoDBExpertDiagnostics.diagnose_buffer_pool_instances(
            pool_size_bytes=512 * 1024 ** 2,  # 512MB
            instances=4,
        )
        self.assertIsNotNone(finding)
        self.assertEqual(finding.severity, "WARN")
        self.assertEqual(finding.suggested_cnf_directives["innodb_buffer_pool_instances"], "1")

    def test_instances_under_1gb_each(self):
        finding = InnoDBExpertDiagnostics.diagnose_buffer_pool_instances(
            pool_size_bytes=4 * 1024 ** 3,  # 4GB
            instances=8,  # 512MB each
        )
        self.assertIsNotNone(finding)
        self.assertEqual(finding.severity, "WARN")
        self.assertEqual(finding.suggested_cnf_directives["innodb_buffer_pool_instances"], "4")

    def test_high_dirty_pages_ratio(self):
        finding = InnoDBExpertDiagnostics.diagnose_dirty_pages_ratio(
            dirty_pages=8000,
            total_pages=10000,
        )
        self.assertIsNotNone(finding)
        self.assertEqual(finding.severity, "BAD")
        self.assertIn("80.00%", finding.root_cause)


if __name__ == "__main__":
    unittest.main()
