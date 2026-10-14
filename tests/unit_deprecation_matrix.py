"""
Unit tests for build.issue_triage.deprecation_matrix
"""

import unittest
from build.issue_triage.deprecation_matrix import DeprecationMatrix


class TestDeprecationMatrix(unittest.TestCase):
    def test_query_cache_removed_in_mysql_8_0(self):
        res = DeprecationMatrix.check_variable(is_mariadb=False, major=8, minor=0, var_name="query_cache_type")
        self.assertIsNotNone(res)
        self.assertEqual(res["status"], "REMOVED")
        self.assertIsNone(res["replacement_var"])

    def test_query_cache_valid_in_mariadb_10_11(self):
        res = DeprecationMatrix.check_variable(is_mariadb=True, major=10, minor=11, var_name="query_cache_type")
        self.assertIsNone(res)

    def test_innodb_log_file_size_deprecated_mysql_8_4(self):
        res = DeprecationMatrix.check_variable(is_mariadb=False, major=8, minor=4, var_name="innodb_log_file_size")
        self.assertIsNotNone(res)
        self.assertEqual(res["status"], "DEPRECATED")
        self.assertEqual(res["replacement_var"], "innodb_redo_log_capacity")


if __name__ == "__main__":
    unittest.main()
