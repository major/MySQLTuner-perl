"""
Unit tests for build.issue_triage.offline_replay_engine
"""

import unittest
from build.issue_triage.offline_replay_engine import OfflineReplayEngine
from build.issue_triage.github_rest_client import GitHubRESTClient


class TestOfflineReplayEngine(unittest.TestCase):
    def setUp(self):
        self.engine = OfflineReplayEngine()

    def test_load_sample_issues(self):
        issues = self.engine.list_issues(state="open")
        self.assertGreaterEqual(len(issues), 3)
        issue881 = self.engine.get_issue(881)
        self.assertIsNotNone(issue881)
        self.assertEqual(issue881["author"], "external_dba")

    def test_add_comment_and_close(self):
        self.engine.add_comment(881, "MySQLTunerBot", "Test reply")
        self.assertEqual(len(self.engine.comments[881]), 1)
        self.engine.close_issue(881, "completed")
        self.assertEqual(self.engine.get_issue(881)["state"], "closed")

    def test_plug_into_rest_client(self):
        mock_transport = self.engine.export_as_transport_mock()
        client = GitHubRESTClient(token="mock", transport_mock=mock_transport)
        
        issue = client.get_issue(883)
        self.assertEqual(issue["number"], 883)
        self.assertEqual(issue["author"], "legacy_migrator")

        client.add_comment(883, "Query cache was removed in MySQL 8.0")
        self.assertEqual(len(self.engine.comments[883]), 1)


if __name__ == "__main__":
    unittest.main()
