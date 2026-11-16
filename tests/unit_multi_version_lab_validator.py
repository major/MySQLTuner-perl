"""
Unit tests for build.issue_triage.multi_version_lab_validator
"""

import tempfile
import unittest
from build.issue_triage.multi_version_lab_validator import MultiVersionLabValidator


class TestMultiVersionLabValidator(unittest.TestCase):
    def test_matrix_validation(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            summary = MultiVersionLabValidator.validate_matrix(tests_dir=tmpdir)
        self.assertTrue(summary["all_matrix_passed"])
        self.assertEqual(summary["total_tested"], 8)


if __name__ == "__main__":
    unittest.main()
