"""
Unit tests for build.issue_triage.ci_proof_linker
"""

import unittest
from build.issue_triage.ci_proof_linker import CIProofLinker


class TestCIProofLinker(unittest.TestCase):
    def test_get_test_file_url(self):
        url = CIProofLinker.get_test_file_url("tests/test_issue_881.t", sha="abcdef123456")
        self.assertEqual(url, "https://github.com/jmrenouard/MySQLTuner-perl/blob/abcdef123456/tests/test_issue_881.t")

    def test_get_ci_run_url(self):
        url = CIProofLinker.get_ci_run_url(run_id="99887766")
        self.assertEqual(url, "https://github.com/jmrenouard/MySQLTuner-perl/actions/runs/99887766")

    def test_get_commit_url(self):
        url = CIProofLinker.get_commit_url(sha="11223344")
        self.assertEqual(url, "https://github.com/jmrenouard/MySQLTuner-perl/commit/11223344")


if __name__ == "__main__":
    unittest.main()
