"""
Unit tests for build.issue_triage.duplicate_detector
"""

import unittest
from build.issue_triage.duplicate_detector import DuplicateIssueDetector


class TestDuplicateDetector(unittest.TestCase):
    def test_compute_fingerprint(self):
        fp = DuplicateIssueDetector.compute_fingerprint(
            db_engine="MySQL",
            db_version="8.4.0",
            variable_names=["innodb_buffer_pool_size", "table_open_cache"],
            error_codes=["MY-011925"],
            perl_line_num=123,
        )
        self.assertIn("db:mysql", fp)
        self.assertIn("ver:8.4.0", fp)
        self.assertIn("innodb_buffer_pool_size,table_open_cache", fp)
        self.assertIn("errs:my-011925", fp)
        self.assertIn("line:123", fp)

    def test_similarity_identical_texts(self):
        text_a = "MySQL 8.4 InnoDB buffer pool size calculation issue"
        text_b = "MySQL 8.4 InnoDB buffer pool size calculation issue"
        cos = DuplicateIssueDetector.cosine_similarity(text_a, text_b)
        self.assertAlmostEqual(cos, 1.0)

    def test_find_duplicates(self):
        existing = [
            {
                "number": 500,
                "title": "MySQL 8.4 buffer pool calculation error",
                "body": "innodb_buffer_pool_size check is wrong on MySQL 8.4 LTS with 64GB RAM",
            },
            {
                "number": 501,
                "title": "Unrelated documentation typo in README",
                "body": "Fix markdown link in contributing guidelines",
            },
        ]
        target_title = "Calculation error in innodb_buffer_pool_size for MySQL 8.4"
        target_body = "On MySQL 8.4 LTS with 64GB RAM, buffer pool warning is incorrect"

        dupes = DuplicateIssueDetector.find_duplicates(target_title, target_body, existing, threshold=0.5)
        self.assertEqual(len(dupes), 1)
        self.assertEqual(dupes[0][0], 500)
        self.assertGreater(dupes[0][1], 0.6)


if __name__ == "__main__":
    unittest.main()
