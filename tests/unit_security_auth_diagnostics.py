"""
Unit tests for build.issue_triage.security_auth_diagnostics
"""

import unittest
from build.issue_triage.security_auth_diagnostics import SecurityAuthDiagnostics


class TestSecurityAuthDiagnostics(unittest.TestCase):
    def test_insecure_transport_and_bind(self):
        vars_ = {
            "require_secure_transport": 0,
            "bind_address": "0.0.0.0",
        }
        findings = SecurityAuthDiagnostics.diagnose_security(vars_, {}, major_version=8, minor_version=4)
        self.assertEqual(len(findings), 2)
        ids = [f.rule_id for f in findings]
        self.assertIn("SEC_TLS_01", ids)
        self.assertIn("SEC_BIND_01", ids)

    def test_mysql_native_password_in_mysql_8_4(self):
        vars_ = {
            "require_secure_transport": 1,
            "bind_address": "127.0.0.1",
            "default_authentication_plugin": "mysql_native_password",
        }
        findings = SecurityAuthDiagnostics.diagnose_security(vars_, {}, major_version=8, minor_version=4)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].rule_id, "SEC_AUTH_01")


if __name__ == "__main__":
    unittest.main()
