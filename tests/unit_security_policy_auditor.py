"""
Unit tests for build.issue_triage.security_policy_auditor
"""

import os
import unittest
from build.issue_triage.security_policy_auditor import SecurityPolicyAuditor


class TestSecurityPolicyAuditor(unittest.TestCase):
    def test_audit_workflow_permissions(self):
        workflow_path = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", ".github", "workflows", "issue_triage.yml")
        )
        passed, issues = SecurityPolicyAuditor.audit_github_workflow_permissions(workflow_path)
        self.assertTrue(passed, f"Workflow permission issues: {issues}")
        self.assertEqual(len(issues), 0)


if __name__ == "__main__":
    unittest.main()
