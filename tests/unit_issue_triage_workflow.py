"""
Unit tests for .github/workflows/issue_triage.yml
"""

import os
import unittest


class TestGitHubActionsWorkflow(unittest.TestCase):
    def test_workflow_file_exists_and_valid(self):
        workflow_path = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", ".github", "workflows", "issue_triage.yml")
        )
        self.assertTrue(os.path.exists(workflow_path))
        with open(workflow_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("issues:", content)
        self.assertIn("triage_orchestrator.py", content)
        self.assertIn("permissions:", content)
        self.assertIn("issues: write", content)


if __name__ == "__main__":
    unittest.main()
