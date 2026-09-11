"""
Unit tests for build.issue_triage.upstream_syncer
"""

import os
import shutil
import tempfile
import unittest

from build.issue_triage.upstream_syncer import UpstreamSyncer
from build.issue_triage.models import IssueAuthorType


class TestUpstreamSyncer(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.syncer = UpstreamSyncer(
            upstream_repo="major/MySQLTuner-perl",
            downstream_repo="jmrenouard/MySQLTuner-perl",
            offline_mode=True,
            dry_run=True,
            output_dir=self.tmpdir,
        )

    def tearDown(self):
        if os.path.exists(self.tmpdir):
            shutil.rmtree(self.tmpdir)

    def test_determine_tags_for_change(self):
        tags_feat = UpstreamSyncer.determine_tags_for_change("feat", "mysql84")
        self.assertIn("enhancement", tags_feat)
        self.assertIn("db:mysql84", tags_feat)

        tags_fix = UpstreamSyncer.determine_tags_for_change("fix", "cve")
        self.assertIn("bug", tags_fix)
        self.assertIn("security", tags_fix)

    def test_format_upstream_issue_payload(self):
        payload = self.syncer.format_upstream_issue_payload(
            title="feat(mysql84): support MySQL 8.4 LTS indicators",
            description="Added support for new redo log and authentication parameters.",
            commit_type="feat",
            scope="mysql84",
            test_file_path="tests/test_mysql84.t",
        )
        self.assertEqual(payload["title"], "feat(mysql84): support MySQL 8.4 LTS indicators")
        self.assertEqual(payload["assignees"], ["jmrenouard"])
        self.assertIn("jmrenouard/MySQLTuner-perl", payload["body"])
        self.assertIn("tests/test_mysql84.t", payload["body"])
        self.assertIn("db:mysql84", payload["labels"])

    def test_triage_upstream_issues(self):
        results = self.syncer.run_all_upstream(limit=5)
        self.assertEqual(len(results), 3)

        # Issue 512: Community reporter on MySQL 8.4
        issue_512 = next(r for r in results if r["issue_number"] == 512)
        self.assertEqual(issue_512["repo"], "major/MySQLTuner-perl")
        self.assertEqual(issue_512["author_type"], "community")
        self.assertTrue(issue_512["invariants_ok"])

        # Issue 513: Maintainer jmrenouard
        issue_513 = next(r for r in results if r["issue_number"] == 513)
        self.assertEqual(issue_513["author_type"], "maintainer")
        self.assertEqual(issue_513["triage_status"], "maintainer_hold")
        self.assertFalse(issue_513["can_auto_close"])


if __name__ == "__main__":
    unittest.main()
