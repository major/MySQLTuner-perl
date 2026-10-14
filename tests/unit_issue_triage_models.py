"""
Unit tests for build.issue_triage.models
"""

import unittest
from build.issue_triage.models import (
    GitHubIssueRecord,
    IssueAuthorType,
    IssueCategory,
    DatabaseEngineType,
    TriageStatus,
    ExtractedMetrics,
    DiagnosticFinding,
    GovernanceDecision,
)


class TestIssueTriageModels(unittest.TestCase):
    def test_author_classification(self):
        record = GitHubIssueRecord(
            number=999,
            title="Test Issue Title",
            author="jmrenouard",
            author_type=IssueAuthorType.MAINTAINER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="Test issue description",
            category=IssueCategory.BUG_DIAGNOSTIC,
            triage_status=TriageStatus.MAINTAINER_HOLD,
        )
        self.assertEqual(record.author_type, IssueAuthorType.MAINTAINER)
        self.assertEqual(record.triage_status, TriageStatus.MAINTAINER_HOLD)

        # Community user
        community_record = GitHubIssueRecord(
            number=1000,
            title="Community Issue",
            author="external_user",
            author_type=IssueAuthorType.COMMUNITY_USER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="Sample bug report",
            category=IssueCategory.BUG_PARSING,
            triage_status=TriageStatus.READY_TO_CLOSE,
        )
        self.assertEqual(community_record.author_type, IssueAuthorType.COMMUNITY_USER)
        self.assertEqual(community_record.triage_status, TriageStatus.READY_TO_CLOSE)

    def test_json_serialization(self):
        record = GitHubIssueRecord(
            number=42,
            title="InnoDB Buffer Pool Overflow",
            author="user123",
            author_type=IssueAuthorType.COMMUNITY_USER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="MySQL 8.4 buffer pool check failed",
            extracted_metrics=ExtractedMetrics(
                db_engine=DatabaseEngineType.MYSQL,
                db_version_raw="8.4.0-LTS",
                db_version_normalized="8.4.0",
                variables={"innodb_buffer_pool_size": "17179869184"},
            ),
            findings=[
                DiagnosticFinding(
                    rule_id="INNODB_BP_001",
                    title="InnoDB Buffer Pool Sizing",
                    severity="OK",
                    root_cause="Appropriate allocation for 32GB RAM instance",
                    confidence_score=0.98,
                    official_doc_url="https://dev.mysql.com/doc/refman/8.4/en/innodb-buffer-pool-resize.html",
                    recommendation="No change needed.",
                    is_already_supported_in_master=True,
                )
            ],
            governance=GovernanceDecision(
                author="user123",
                author_type=IssueAuthorType.COMMUNITY_USER,
                can_auto_close=True,
                response_markdown="Thank you @user123 for reporting!",
            ),
        )
        data = record.to_dict()
        self.assertEqual(data["number"], 42)
        self.assertEqual(data["extracted_metrics"]["db_engine"], "MySQL")
        self.assertEqual(len(data["findings"]), 1)
        json_str = record.to_json()
        self.assertIn("17179869184", json_str)


if __name__ == "__main__":
    unittest.main()
