"""
Unit tests for build.issue_triage.github_cli_wrapper
"""

import unittest
from unittest.mock import patch, MagicMock
from build.issue_triage.github_cli_wrapper import GitHubCLIWrapper, GitHubCLIError


class TestGitHubCLIWrapper(unittest.TestCase):
    def setUp(self):
        self.wrapper = GitHubCLIWrapper(binary_path="/usr/bin/gh")

    def test_is_available(self):
        self.assertTrue(self.wrapper.is_available())

    @patch("subprocess.Popen")
    def test_list_issues_success(self, mock_popen):
        mock_proc = MagicMock()
        mock_proc.communicate.return_value = ('[{"number": 12, "title": "Test gh issue"}]', "")
        mock_proc.returncode = 0
        mock_popen.return_value = mock_proc

        issues = self.wrapper.list_issues(limit=5)
        self.assertEqual(len(issues), 1)
        self.assertEqual(issues[0]["number"], 12)

    @patch("subprocess.Popen")
    def test_view_issue_failure(self, mock_popen):
        mock_proc = MagicMock()
        mock_proc.communicate.return_value = ("", "HTTP 404: Not Found")
        mock_proc.returncode = 1
        mock_popen.return_value = mock_proc

        with self.assertRaises(GitHubCLIError):
            self.wrapper.view_issue(99999)


if __name__ == "__main__":
    unittest.main()
