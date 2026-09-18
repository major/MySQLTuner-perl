"""
Unit tests for build.issue_triage.github_ingest
"""

import unittest
from build.issue_triage.github_ingest import GitHubIngestionService
from build.issue_triage.offline_replay_engine import OfflineReplayEngine
from build.issue_triage.models import IssueAuthorType, TriageStatus


class TestGitHubIngestionService(unittest.TestCase):
    def setUp(self):
        self.offline = OfflineReplayEngine()
        self.service = GitHubIngestionService(offline_engine=self.offline)

    def test_fetch_and_transform_all_issues(self):
        records = self.service.fetch_open_issues(limit=10)
        self.assertGreaterEqual(len(records), 3)

        # Check Issue 881 (Community User)
        rec881 = next(r for r in records if r.number == 881)
        self.assertEqual(rec881.author, "external_dba")
        self.assertEqual(rec881.author_type, IssueAuthorType.COMMUNITY_USER)
        self.assertEqual(rec881.triage_status, TriageStatus.PENDING_INGESTION)
        self.assertIn("innodb_buffer_pool_size", rec881.body)

        # Check Issue 882 (Maintainer jmrenouard)
        rec882 = next(r for r in records if r.number == 882)
        self.assertEqual(rec882.author, "jmrenouard")
        self.assertEqual(rec882.author_type, IssueAuthorType.MAINTAINER)
        self.assertEqual(rec882.triage_status, TriageStatus.MAINTAINER_HOLD)

    def test_author_classification(self):
        self.assertEqual(self.service.classify_author("jmrenouard"), IssueAuthorType.MAINTAINER)
        self.assertEqual(self.service.classify_author("JMRENOUARD"), IssueAuthorType.MAINTAINER)
        self.assertEqual(self.service.classify_author("dependabot[bot]"), IssueAuthorType.BOT)
        self.assertEqual(self.service.classify_author("coderabbit[bot]"), IssueAuthorType.BOT)
        self.assertEqual(self.service.classify_author("random_contributor"), IssueAuthorType.COMMUNITY_USER)


if __name__ == "__main__":
    unittest.main()
