"""
Unit tests for build.issue_triage.triage_cleaner
"""

import os
import shutil
import tempfile
import time
import unittest
from build.issue_triage.triage_cleaner import TriageCleaner


class TestTriageCleaner(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        if os.path.exists(self.tmpdir):
            shutil.rmtree(self.tmpdir)

    def test_clean_reports_directory_retention(self):
        # Create 15 report files
        for i in range(15):
            path = os.path.join(self.tmpdir, f"issue_{i}_report.md")
            with open(path, "w") as f:
                f.write(f"Report {i}")
            # Set artificial mtime
            os.utime(path, (time.time() + i, time.time() + i))

        deleted = TriageCleaner.clean_reports_directory(self.tmpdir, keep_count=10)
        self.assertEqual(deleted, 5)
        remaining = [f for f in os.listdir(self.tmpdir) if f.endswith(".md")]
        self.assertEqual(len(remaining), 10)


if __name__ == "__main__":
    unittest.main()
