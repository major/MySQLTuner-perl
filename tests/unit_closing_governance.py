"""
Unit tests for build.issue_triage.closing_governance
"""

import unittest
from build.issue_triage.closing_governance import ClosingGovernanceEngine
from build.issue_triage.models import (
    GitHubIssueRecord,
    IssueAuthorType,
    ExtractedMetrics,
    TestProofArtifact,
    DatabaseEngineType,
    TriageStatus,
)


class TestClosingGovernanceEngine(unittest.TestCase):
    def test_maintainer_issue_shield(self):
        issue = GitHubIssueRecord(
            number=999,
            title="Roadmap MariaDB 11.4",
            author="jmrenouard",
            author_type=IssueAuthorType.MAINTAINER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="Tracking features",
            triage_status=TriageStatus.MAINTAINER_HOLD,
            test_proofs=[
                TestProofArtifact(
                    test_file_path="tests/test_issue_999.t",
                    test_name="Test",
                    subtest_count=2,
                    syntax_valid=True,
                    execution_passed=True,
                    output_log_excerpt="ok",
                    reproduce_command="perl",
                )
            ],
        )
        decision = ClosingGovernanceEngine.evaluate(issue)
        self.assertFalse(decision.can_auto_close)
        self.assertIn("strictly prohibited", decision.close_action_blocked_reason)
        self.assertIn("triage:maintainer-review", decision.target_labels_to_add)

    def test_community_issue_auto_close_allowed_when_tested(self):
        issue = GitHubIssueRecord(
            number=888,
            title="MySQL 8.4 tuning question",
            author="community_user",
            author_type=IssueAuthorType.COMMUNITY_USER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="Help needed",
            triage_status=TriageStatus.DIAGNOSED,
            extracted_metrics=ExtractedMetrics(
                db_engine=DatabaseEngineType.MYSQL,
                db_version_normalized="8.4.0",
            ),
            test_proofs=[
                TestProofArtifact(
                    test_file_path="tests/test_issue_888.t",
                    test_name="Test 888",
                    subtest_count=2,
                    syntax_valid=True,
                    execution_passed=True,
                    output_log_excerpt="ok",
                    reproduce_command="perl",
                )
            ],
        )
        decision = ClosingGovernanceEngine.evaluate(issue)
        self.assertTrue(decision.can_auto_close)
        self.assertIsNone(decision.close_action_blocked_reason)
        self.assertIn("triage:resolved", decision.target_labels_to_add)


if __name__ == "__main__":
    unittest.main()
