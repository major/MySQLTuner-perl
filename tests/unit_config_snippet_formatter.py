"""
Unit tests for build.issue_triage.config_snippet_formatter
"""

import unittest
from build.issue_triage.config_snippet_formatter import ConfigSnippetFormatter
from build.issue_triage.models import DiagnosticFinding


class TestConfigSnippetFormatter(unittest.TestCase):
    def test_format_cnf_block(self):
        findings = [
            DiagnosticFinding(
                rule_id="RULE_01",
                title="Buffer Pool Sizing",
                severity="BAD",
                root_cause="Low hit rate",
                confidence_score=0.95,
                official_doc_url="https://dev.mysql.com",
                recommendation="Increase pool size",
                suggested_cnf_directives={"innodb_buffer_pool_size": "16G"},
            ),
            DiagnosticFinding(
                rule_id="RULE_02",
                title="Open Files Limit",
                severity="BAD",
                root_cause="Low FD limit",
                confidence_score=0.95,
                official_doc_url="https://dev.mysql.com",
                recommendation="Increase FDs",
                suggested_cnf_directives={"open_files_limit": "65535"},
            ),
        ]
        cnf = ConfigSnippetFormatter.format_cnf_block(findings, is_mariadb=False)
        self.assertIn("[mysqld]", cnf)
        self.assertIn("innodb_buffer_pool_size = 16G", cnf)
        self.assertIn("open_files_limit = 65535", cnf)
        self.assertIn("Buffer Pool Sizing", cnf)


if __name__ == "__main__":
    unittest.main()
