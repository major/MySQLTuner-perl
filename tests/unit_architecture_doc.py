"""
Unit tests for documentation/ISSUE_TRIAGE_ARCHITECTURE.md
"""

import os
import unittest


class TestIssueTriageArchitectureDoc(unittest.TestCase):
    def test_architecture_doc_structure(self):
        doc_path = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "documentation", "ISSUE_TRIAGE_ARCHITECTURE.md")
        )
        self.assertTrue(os.path.exists(doc_path))
        with open(doc_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("6-Module Subsystem Architecture", content)
        self.assertIn("Maintainer Shield", content)
        self.assertIn("make test-triage", content)


if __name__ == "__main__":
    unittest.main()
