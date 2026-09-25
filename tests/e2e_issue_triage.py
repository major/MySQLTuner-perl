"""
End-to-End Integration Test Suite for MySQLTuner Issue Triage System
"""

import os
import shutil
import tempfile
import unittest

from build.issue_triage.models import (
    GitHubIssueRecord,
    IssueAuthorType,
    ExtractedMetrics,
    DatabaseEngineType,
    TriageStatus,
)
from build.issue_triage.triage_orchestrator import IssueTriageOrchestrator


class TestE2EIssueTriageSystem(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.orchestrator = IssueTriageOrchestrator(
            repo="jmrenouard/MySQLTuner-perl",
            offline_mode=True,
            dry_run=True,
            output_dir=self.tmpdir,
        )

    def tearDown(self):
        if os.path.exists(self.tmpdir):
            shutil.rmtree(self.tmpdir)

    def test_e2e_scenario_community_mysql_8_4(self):
        # Issue #881 in offline fixtures is community MySQL 8.4 inquiry
        issue_881 = self.orchestrator.ingest_facade.fetch_single_issue(881)
        self.assertIsNotNone(issue_881)

        result = self.orchestrator.process_issue(issue_881)
        self.assertEqual(result["issue_number"], 881)
        self.assertEqual(result["author_type"], "community")
        self.assertTrue(result["invariants_ok"])
        self.assertTrue(result["can_auto_close"])
        self.assertTrue(os.path.exists(result["report_file"]))

        with open(result["report_file"], "r", encoding="utf-8") as f:
            report_text = f.read()
        self.assertIn("Issue #881", report_text)
        self.assertIn("Automated Test Proof", report_text)

    def test_e2e_scenario_maintainer_shield(self):
        # Issue #882 in offline fixtures is maintainer jmrenouard issue
        issue_882 = self.orchestrator.ingest_facade.fetch_single_issue(882)
        self.assertIsNotNone(issue_882)

        result = self.orchestrator.process_issue(issue_882)
        self.assertEqual(result["issue_number"], 882)
        self.assertEqual(result["author_type"], "maintainer")
        self.assertEqual(result["triage_status"], "maintainer_hold")
        self.assertFalse(result["can_auto_close"])

    def test_e2e_scenario_legacy_mariadb_migration(self):
        # Issue #883 in offline fixtures is MariaDB query cache deprecation
        issue_883 = self.orchestrator.ingest_facade.fetch_single_issue(883)
        self.assertIsNotNone(issue_883)

        result = self.orchestrator.process_issue(issue_883)
        self.assertEqual(result["issue_number"], 883)
        self.assertEqual(result["triage_status"], "diagnosed")
        self.assertTrue(result["can_auto_close"])


if __name__ == "__main__":
    unittest.main()
