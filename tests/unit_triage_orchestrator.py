"""
Unit tests for build.issue_triage.triage_orchestrator
"""

import os
import tempfile
import unittest
from build.issue_triage.triage_orchestrator import IssueTriageOrchestrator
from build.issue_triage.models import (
    GitHubIssueRecord,
    IssueAuthorType,
    ExtractedMetrics,
    DatabaseEngineType,
    TriageStatus,
)


class TestIssueTriageOrchestrator(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.orchestrator = IssueTriageOrchestrator(
            repo="jmrenouard/MySQLTuner-perl",
            offline_mode=True,
            dry_run=True,
            output_dir=self.tmpdir,
        )

    def test_run_offline_issue_triage(self):
        results = self.orchestrator.run_all(limit=5)
        self.assertGreater(len(results), 0)
        first = results[0]
        self.assertIn("issue_number", first)
        self.assertIn("triage_status", first)
        self.assertIn("DRY_RUN_SIMULATED", first["actions_taken"])
        self.assertTrue(os.path.exists(first["report_file"]))


if __name__ == "__main__":
    unittest.main()
