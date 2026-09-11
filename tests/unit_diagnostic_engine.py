"""
Unit tests for build.issue_triage.diagnostic_engine
"""

import unittest
from build.issue_triage.diagnostic_engine import DiagnosticEngine
from build.issue_triage.models import (
    GitHubIssueRecord,
    IssueAuthorType,
    TriageStatus,
    DatabaseEngineType,
)


class TestDiagnosticEngine(unittest.TestCase):
    def setUp(self):
        self.engine = DiagnosticEngine()

    def test_diagnose_mysql_8_4_buffer_pool_and_deprecation(self):
        issue = GitHubIssueRecord(
            number=999,
            title="MySQL 8.4 tuning inquiry",
            author="dev_user",
            author_type=IssueAuthorType.COMMUNITY_USER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="""
Running on MySQL 8.4.0-LTS with 64G RAM.
innodb_buffer_pool_size = 4G
innodb_buffer_pool_instances = 8
query_cache_type = 0
open_files_limit = 2000
table_open_cache = 4000
max_connections = 500
""",
        )
        diagnosed = self.engine.analyze_issue(issue)
        self.assertEqual(diagnosed.extracted_metrics.db_engine, DatabaseEngineType.MYSQL)
        self.assertEqual(diagnosed.extracted_metrics.db_version_normalized, "8.4.0")
        self.assertGreater(len(diagnosed.findings), 2)
        
        rule_ids = [f.rule_id for f in diagnosed.findings]
        self.assertIn("DEP_VAR_QUERY_CACHE_TYPE", rule_ids)
        self.assertIn("INNODB_BP_INST_02", rule_ids)
        self.assertIn("TABLE_CACHE_FDS_01", rule_ids)
        self.assertEqual(diagnosed.triage_status, TriageStatus.DIAGNOSED)

    def test_maintainer_issue_retains_hold(self):
        issue = GitHubIssueRecord(
            number=1000,
            title="Roadmap MariaDB 11.4",
            author="jmrenouard",
            author_type=IssueAuthorType.MAINTAINER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="Tracking indicators for MariaDB 11.4 LTS",
        )
        diagnosed = self.engine.analyze_issue(issue)
        self.assertEqual(diagnosed.triage_status, TriageStatus.MAINTAINER_HOLD)


if __name__ == "__main__":
    unittest.main()
