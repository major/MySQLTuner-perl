"""
Unit tests for build.issue_triage.pre_closing_checklist
"""

import unittest
from build.issue_triage.pre_closing_checklist import PreClosingChecklist
from build.issue_triage.models import (
    GitHubIssueRecord,
    IssueAuthorType,
    DiagnosticFinding,
    TestProofArtifact,
)


class TestPreClosingChecklist(unittest.TestCase):
    def test_passing_community_issue(self):
        issue = GitHubIssueRecord(
            number=123,
            title="Valid Issue",
            author="user_a",
            author_type=IssueAuthorType.COMMUNITY_USER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="Body",
            findings=[
                DiagnosticFinding(
                    rule_id="R1",
                    title="Finding",
                    severity="OK",
                    root_cause="None",
                    confidence_score=0.99,
                    official_doc_url="https://dev.mysql.com",
                    recommendation="None",
                )
            ],
            test_proofs=[
                TestProofArtifact(
                    test_file_path="tests/t.t",
                    test_name="Test",
                    subtest_count=1,
                    syntax_valid=True,
                    execution_passed=True,
                    output_log_excerpt="ok",
                    reproduce_command="perl",
                )
            ],
        )
        resp = "### Technical Response\nHere is the detailed diagnosis with verified results."
        res = PreClosingChecklist.audit_invariants(issue, resp, commit_sha="abcdef12", attempt_close=True)
        self.assertTrue(res.all_invariants_satisfied)
        self.assertEqual(len(res.failed_invariants), 0)

    def test_failing_maintainer_closure_attempt(self):
        issue = GitHubIssueRecord(
            number=124,
            title="Maintainer Item",
            author="jmrenouard",
            author_type=IssueAuthorType.MAINTAINER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="Body",
        )
        resp = "### Technical Response\nSummary."
        res = PreClosingChecklist.audit_invariants(issue, resp, commit_sha="abcdef12", attempt_close=True)
        self.assertFalse(res.all_invariants_satisfied)
        self.assertTrue(any("INVARIANT_AUTHOR_NON_MAINTAINER" in f for f in res.failed_invariants))


if __name__ == "__main__":
    unittest.main()
