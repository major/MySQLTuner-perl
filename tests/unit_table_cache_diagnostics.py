"""
Unit tests for build.issue_triage.table_cache_diagnostics
"""

import unittest
from build.issue_triage.table_cache_diagnostics import TableCacheDiagnostics


class TestTableCacheDiagnostics(unittest.TestCase):
    def test_insufficient_open_files_limit(self):
        findings = TableCacheDiagnostics.diagnose_table_cache_and_descriptors(
            table_open_cache=4000,
            table_definition_cache=1400,
            open_files_limit=5000,  # Required: max(10 + 500 + 8000 = 8510, 2500) -> 8510
            max_connections=500,
            table_open_cache_instances=16,
        )
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].severity, "BAD")
        self.assertEqual(findings[0].rule_id, "TABLE_CACHE_FDS_01")
        self.assertIn("8510", findings[0].suggested_cnf_directives["open_files_limit"])

    def test_single_instance_with_large_cache(self):
        findings = TableCacheDiagnostics.diagnose_table_cache_and_descriptors(
            table_open_cache=4000,
            table_definition_cache=1400,
            open_files_limit=65535,
            max_connections=500,
            table_open_cache_instances=1,
        )
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].severity, "WARN")
        self.assertEqual(findings[0].rule_id, "TABLE_CACHE_INST_01")


if __name__ == "__main__":
    unittest.main()
