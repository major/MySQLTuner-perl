"""
Unit tests for build.issue_triage.multi_version_lab_validator
"""

import unittest
from build.issue_triage.multi_version_lab_validator import MultiVersionLabValidator


class TestMultiVersionLabValidator(unittest.TestCase):
    def test_matrix_validation(self):
        summary = MultiVersionLabValidator.validate_matrix()
        self.assertTrue(summary["all_matrix_passed"])
        self.assertEqual(summary["total_tested"], 8)


if __name__ == "__main__":
    unittest.main()
