"""
Unit tests for build.issue_triage.reproducibility_reporter
"""

import unittest
from build.issue_triage.reproducibility_reporter import ReproducibilityReporter
from build.issue_triage.models import (
    GitHubIssueRecord,
    IssueAuthorType,
    ExtractedMetrics,
    DiagnosticFinding,
    TestProofArtifact,
    DatabaseEngineType,
    TriageStatus,
)


class TestReproducibilityReporter(unittest.TestCase):
    def test_generate_markdown_report(self):
        issue = GitHubIssueRecord(
            number=881,
            title="MySQL 8.4 buffer pool check",
            author="external_dev",
            author_type=IssueAuthorType.COMMUNITY_USER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="Sample body",
            triage_status=TriageStatus.DIAGNOSED,
            extracted_metrics=ExtractedMetrics(
                db_engine=DatabaseEngineType.MYSQL,
                db_version_normalized="8.4.0",
            ),
            findings=[
                DiagnosticFinding(
                    rule_id="RULE_INNODB_HITRATE_01",
                    title="Low Hit Rate",
                    severity="BAD",
                    root_cause="Hit rate 89%",
                    confidence_score=0.95,
                    official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/innodb-buffer-pool.html",
                    recommendation="Increase pool size",
                )
            ],
            test_proofs=[
                TestProofArtifact(
                    test_file_path="tests/test_issue_881.t",
                    test_name="Issue #881 Verification",
                    subtest_count=2,
                    syntax_valid=True,
                    execution_passed=True,
                    output_log_excerpt="ok 1 - subtest passed",
                    reproduce_command="perl -I. tests/test_issue_881.t",
                )
            ],
        )
        report = ReproducibilityReporter.generate_markdown_report(issue)
        self.assertIn("Issue #881", report)
        self.assertIn("@external_dev", report)
        self.assertIn("RULE_INNODB_HITRATE_01", report)
        self.assertIn("tests/test_issue_881.t", report)
        self.assertIn("perl -I. tests/test_issue_881.t", report)


if __name__ == "__main__":
    unittest.main()
