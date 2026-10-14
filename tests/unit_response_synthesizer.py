"""
Unit tests for build.issue_triage.response_synthesizer
"""

import unittest
from build.issue_triage.response_synthesizer import ResponseSynthesizer
from build.issue_triage.models import (
    GitHubIssueRecord,
    IssueAuthorType,
    ExtractedMetrics,
    DiagnosticFinding,
    TestProofArtifact,
    DatabaseEngineType,
    TriageStatus,
)


class TestResponseSynthesizer(unittest.TestCase):
    def test_community_user_warm_response(self):
        issue = GitHubIssueRecord(
            number=404,
            title="MySQL 8.4 table cache issue",
            author="alex_dba",
            author_type=IssueAuthorType.COMMUNITY_USER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="Sample body",
            extracted_metrics=ExtractedMetrics(
                db_engine=DatabaseEngineType.MYSQL,
                db_version_normalized="8.4.0",
            ),
            findings=[
                DiagnosticFinding(
                    rule_id="TABLE_CACHE_01",
                    title="Table Cache Low",
                    severity="WARN",
                    root_cause="Open files limit too low",
                    confidence_score=0.95,
                    official_doc_url="https://dev.mysql.com",
                    recommendation="Increase open files",
                    suggested_cnf_directives={"open_files_limit": "65535"},
                )
            ],
            test_proofs=[
                TestProofArtifact(
                    test_file_path="tests/test_issue_404.t",
                    test_name="Issue #404 test",
                    subtest_count=2,
                    syntax_valid=True,
                    execution_passed=True,
                    output_log_excerpt="ok 1 - passed",
                    reproduce_command="perl -I. tests/test_issue_404.t",
                )
            ],
        )
        comment = ResponseSynthesizer.compose_comment(issue)
        self.assertIn("Hello @alex_dba,", comment)
        self.assertIn("Thank you very much for reporting this issue", comment)
        self.assertIn("open_files_limit = 65535", comment)
        self.assertIn("tests/test_issue_404.t", comment)

    def test_maintainer_brief(self):
        issue = GitHubIssueRecord(
            number=500,
            title="Internal Tracking Item",
            author="jmrenouard",
            author_type=IssueAuthorType.MAINTAINER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="Tracking feature",
        )
        comment = ResponseSynthesizer.compose_comment(issue)
        self.assertIn("Internal Maintainer Technical Brief", comment)
        self.assertNotIn("Thank you very much", comment)
        self.assertIn("Auto-close disabled", comment)


if __name__ == "__main__":
    unittest.main()
