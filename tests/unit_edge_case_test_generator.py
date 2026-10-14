"""
Unit tests for build.issue_triage.edge_case_test_generator
"""

import os
import subprocess
import unittest
from build.issue_triage.edge_case_test_generator import EdgeCaseTestGenerator


class TestEdgeCaseTestGenerator(unittest.TestCase):
    def setUp(self):
        self.gen = EdgeCaseTestGenerator()

    def test_generate_and_execute_resilience_test(self):
        test_path = self.gen.generate_resilience_test_file()
        self.assertTrue(os.path.exists(test_path))

        # Execute test via Perl
        proc = subprocess.run(
            ["perl", "-I.", "-Itests", test_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, f"Perl test failed: {proc.stderr}")
        self.assertIn("1..3", proc.stdout)


if __name__ == "__main__":
    unittest.main()
