"""
Unit tests for build.issue_triage.sanitizer
"""

import unittest
from build.issue_triage.sanitizer import TextSanitizer


class TestTextSanitizer(unittest.TestCase):
    def test_strip_ansi_codes(self):
        colored_str = "\x1b[31m[!!]\x1b[0m High fragmented tables found: \x1b[32m12\x1b[0m"
        clean = TextSanitizer.strip_ansi(colored_str)
        self.assertEqual(clean, "[!!] High fragmented tables found: 12")

    def test_strip_dangerous_html(self):
        raw = "Text with <!-- secret comment --> and <script>alert('xss');</script> embedded."
        clean = TextSanitizer.strip_dangerous_html(raw)
        self.assertNotIn("secret comment", clean)
        self.assertNotIn("alert('xss')", clean)
        self.assertIn("Text with", clean)

    def test_redact_github_tokens(self):
        raw = "My gh token is ghp_123456789012345678901234567890123456 in issue."
        clean, count = TextSanitizer.redact_secrets(raw)
        self.assertGreater(count, 0)
        self.assertNotIn("ghp_123456789012345678901234567890123456", clean)
        self.assertIn("[REDACTED_GITHUB_TOKEN]", clean)

    def test_redact_mysql_password_cli(self):
        raw = "Run: mysql -u root -pSuperSecretPass123! -h 127.0.0.1"
        clean, count = TextSanitizer.redact_secrets(raw)
        self.assertGreater(count, 0)
        self.assertNotIn("SuperSecretPass123!", clean)
        self.assertIn("-p[REDACTED_PASSWORD]", clean)

    def test_redact_mysql_connection_uri(self):
        raw = "Database connection: mysql://admin:P@ssword123@db.prod.internal:3306/app_db"
        clean, count = TextSanitizer.redact_secrets(raw)
        self.assertGreater(count, 0)
        self.assertNotIn("P@ssword123", clean)
        self.assertIn("mysql://admin:[REDACTED_PASSWORD]@db.prod.internal", clean)

    def test_normalize_full_pipeline(self):
        dirty = "\x1b[33mWarning\x1b[0m\r\npassword = super_secret\r\n<!-- comment -->\x00Clean line."
        normalized = TextSanitizer.normalize_text(dirty)
        self.assertNotIn("\x1b", normalized)
        self.assertNotIn("\r", normalized)
        self.assertNotIn("super_secret", normalized)
        self.assertNotIn("comment", normalized)
        self.assertNotIn("\x00", normalized)
        self.assertIn("Warning\npassword = [REDACTED_CREDENTIAL]\nClean line.", normalized)


if __name__ == "__main__":
    unittest.main()
