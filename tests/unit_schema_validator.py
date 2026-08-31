"""
Unit tests for build.issue_triage.schema_validator
"""

import unittest
from build.issue_triage.schema_validator import IssueSchemaValidator, SchemaValidationError


class TestSchemaValidator(unittest.TestCase):
    def setUp(self):
        self.validator = IssueSchemaValidator()

    def test_valid_payload(self):
        payload = {
            "number": 100,
            "title": "MySQL 8.4 connection timeout",
            "author": "dev_user",
            "author_type": "community",
            "created_at": "2026-08-22T00:00:00Z",
            "updated_at": "2026-08-22T00:00:00Z",
            "state": "open",
            "body": "Detailed issue description",
            "category": "bug:diagnostic",
            "triage_status": "diagnosed",
            "findings": [
                {
                    "rule_id": "CONN_TIMEOUT_01",
                    "title": "Wait Timeout check",
                    "severity": "WARN",
                    "root_cause": "wait_timeout set too low",
                    "confidence_score": 0.95,
                    "official_doc_url": "https://dev.mysql.com/doc/refman/8.4/en/server-system-variables.html#sysvar_wait_timeout",
                    "recommendation": "Increase wait_timeout to 600",
                }
            ],
            "test_proofs": [
                {
                    "test_file_path": "tests/test_issue_100.t",
                    "test_name": "Wait Timeout Check Issue #100",
                    "subtest_count": 2,
                    "syntax_valid": True,
                    "execution_passed": True,
                    "output_log_excerpt": "ok 1 - Wait timeout detected",
                    "reproduce_command": "perl -I. tests/test_issue_100.t",
                }
            ],
        }
        is_valid, errors = self.validator.validate_dict(payload)
        self.assertTrue(is_valid, f"Validation failed with errors: {errors}")
        self.assertEqual(len(errors), 0)

    def test_invalid_payload_missing_required(self):
        payload = {
            "number": 101,
            # missing title, author, state, etc.
        }
        is_valid, errors = self.validator.validate_dict(payload)
        self.assertFalse(is_valid)
        self.assertTrue(any("Missing required field" in e for e in errors))

    def test_invalid_author_type_enum(self):
        payload = {
            "number": 102,
            "title": "Invalid Author Type",
            "author": "hacker",
            "author_type": "alien_author",
            "created_at": "2026-08-22T00:00:00Z",
            "updated_at": "2026-08-22T00:00:00Z",
            "state": "open",
            "body": "Body",
        }
        is_valid, errors = self.validator.validate_dict(payload)
        self.assertFalse(is_valid)
        self.assertTrue(any("Invalid 'author_type'" in e for e in errors))

    def test_validate_or_raise_exception(self):
        payload = {"number": -5}
        with self.assertRaises(SchemaValidationError):
            self.validator.validate_or_raise(payload)


if __name__ == "__main__":
    unittest.main()
