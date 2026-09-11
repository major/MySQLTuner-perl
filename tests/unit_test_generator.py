"""
Unit tests for build.issue_triage.test_generator
"""

import os
import unittest
from build.issue_triage.test_generator import PerlTestGenerator
from build.issue_triage.models import (
    GitHubIssueRecord,
    IssueAuthorType,
    ExtractedMetrics,
    DatabaseEngineType,
)


class TestPerlTestGenerator(unittest.TestCase):
    def setUp(self):
        self.gen = PerlTestGenerator()

    def test_generate_and_execute_test(self):
        issue = GitHubIssueRecord(
            number=9999,
            title="Automated Test Generation Verification",
            author="unit_test_author",
            author_type=IssueAuthorType.COMMUNITY_USER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="Sample issue description",
            extracted_metrics=ExtractedMetrics(
                db_engine=DatabaseEngineType.MYSQL,
                db_version_raw="8.4.0-LTS",
                db_version_normalized="8.4.0",
                variables={"innodb_buffer_pool_size": 17179869184, "table_open_cache": 4000},
            ),
        )
        artifact = self.gen.write_and_verify_test(issue)
        self.assertTrue(artifact.syntax_valid)
        self.assertTrue(artifact.execution_passed)
        self.assertEqual(artifact.test_file_path, "tests/test_issue_9999.t")

        # Cleanup generated test
        real_path = os.path.join(self.gen.output_tests_dir, "test_issue_9999.t")
        if os.path.exists(real_path):
            os.remove(real_path)


if __name__ == "__main__":
    unittest.main()
