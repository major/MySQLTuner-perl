"""
Unit tests for build.issue_triage.rule_evaluator
"""

import unittest
from build.issue_triage.rule_evaluator import RuleEvaluator


class TestRuleEvaluator(unittest.TestCase):
    def test_buffer_pool_low_hit_rate(self):
        status = {
            "innodb_buffer_pool_reads": 1000,
            "innodb_buffer_pool_read_requests": 10000,
        }
        vars_ = {"innodb_buffer_pool_size": 1073741824}
        finding = RuleEvaluator.eval_buffer_pool_hit_rate(status, vars_)
        self.assertIsNotNone(finding)
        self.assertEqual(finding.severity, "BAD")
        self.assertIn("90.00%", finding.root_cause)

    def test_buffer_pool_optimal_hit_rate(self):
        status = {
            "innodb_buffer_pool_reads": 10,
            "innodb_buffer_pool_read_requests": 10000,
        }
        vars_ = {"innodb_buffer_pool_size": 17179869184}
        finding = RuleEvaluator.eval_buffer_pool_hit_rate(status, vars_)
        self.assertIsNotNone(finding)
        self.assertEqual(finding.severity, "OK")

    def test_tmp_tables_on_disk(self):
        status = {
            "created_tmp_disk_tables": 500,
            "created_tmp_tables": 500,
        }
        finding = RuleEvaluator.eval_tmp_tables_disk(status, {})
        self.assertIsNotNone(finding)
        self.assertEqual(finding.severity, "BAD")
        self.assertIn("50.00%", finding.root_cause)


if __name__ == "__main__":
    unittest.main()
