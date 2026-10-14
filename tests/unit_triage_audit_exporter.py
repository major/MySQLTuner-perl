"""
Unit tests for build.issue_triage.triage_audit_exporter
"""

import os
import shutil
import tempfile
import unittest
from build.issue_triage.triage_audit_exporter import TriageAuditExporter


class TestTriageAuditExporter(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        if os.path.exists(self.tmpdir):
            shutil.rmtree(self.tmpdir)

    def test_export_audit(self):
        issues = [
            {
                "issue_number": 881,
                "title": "MySQL 8.4 tuning question",
                "author": "external_dev",
                "author_type": "community",
                "triage_status": "diagnosed",
                "can_auto_close": True,
                "invariants_ok": True,
            },
            {
                "issue_number": 882,
                "title": "Roadmap MariaDB 11.4",
                "author": "jmrenouard",
                "author_type": "maintainer",
                "triage_status": "maintainer_hold",
                "can_auto_close": False,
                "invariants_ok": True,
            },
        ]
        files = TriageAuditExporter.export_audit(issues, self.tmpdir)
        self.assertTrue(os.path.exists(files["audit_json"]))
        self.assertTrue(os.path.exists(files["summary_json"]))
        self.assertTrue(os.path.exists(files["dashboard_md"]))

        with open(files["dashboard_md"], "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("MySQLTuner Autonomous Issue Triage Dashboard", content)
        self.assertIn("#881", content)
        self.assertIn("#882", content)


if __name__ == "__main__":
    unittest.main()
