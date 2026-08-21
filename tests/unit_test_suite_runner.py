"""
Unit tests for build.issue_triage.test_suite_runner
"""

import unittest
from build.issue_triage.test_suite_runner import TestSuiteRunner


class TestTestSuiteRunner(unittest.TestCase):
    def setUp(self):
        self.runner = TestSuiteRunner()

    def test_run_single_test_bridge(self):
        import os
        test_path = os.path.join(self.runner.tests_dir, "unit_issue_triage_bridge.t")
        if os.path.exists(test_path):
            result = self.runner.run_single_test(test_path)
            self.assertTrue(result.passed)
            self.assertGreater(result.passed_assertions, 0)
            self.assertEqual(result.failed_assertions, 0)
            self.assertGreaterEqual(result.subtest_count, 3)

    def test_run_suite_triage_tests(self):
        summary = self.runner.run_suite(file_pattern=r"^unit_issue_triage_bridge\.t$")
        self.assertEqual(summary.total_tests_run, 1)
        self.assertEqual(summary.passed_tests, 1)
        self.assertEqual(summary.failed_tests, 0)
        self.assertEqual(summary.success_rate, 100.0)


if __name__ == "__main__":
    unittest.main()
