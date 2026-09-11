"""
Unit tests for build.issue_triage.roadmap_sync_engine
"""

import tempfile
import os
import unittest
from build.issue_triage.roadmap_sync_engine import RoadmapSyncEngine
from build.issue_triage.models import GitHubIssueRecord, IssueAuthorType, TriageStatus


class TestRoadmapSyncEngine(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".md")
        self.tmp.write(b"""# Project Roadmap
- [ ] Support MySQL 8.4 LTS indicators (#957)
- [ ] Unrelated feature
""")
        self.tmp.close()
        self.engine = RoadmapSyncEngine(roadmap_path=self.tmp.name)

    def tearDown(self):
        if os.path.exists(self.tmp.name):
            os.remove(self.tmp.name)

    def test_sync_resolved_issues(self):
        issue = GitHubIssueRecord(
            number=957,
            title="Support MySQL 8.4 LTS indicators",
            author="dev",
            author_type=IssueAuthorType.COMMUNITY_USER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="Fix indicators",
            triage_status=TriageStatus.READY_TO_CLOSE,
        )
        count, new_text = self.engine.sync_resolved_issues([issue], dry_run=False)
        self.assertEqual(count, 1)
        self.assertIn("- [x] Support MySQL 8.4 LTS indicators (#957)", new_text)


if __name__ == "__main__":
    unittest.main()
