"""
Unit tests for build.issue_triage.github_rest_client
"""

import unittest
from build.issue_triage.github_rest_client import GitHubRESTClient, GitHubAPIError


class MockTransport:
    def __init__(self):
        self.recorded_requests = []
        self.remaining_rate_limit = 4990

    def request(self, endpoint, method="GET", params=None, data=None):
        self.recorded_requests.append({
            "endpoint": endpoint,
            "method": method,
            "params": params,
            "data": data,
        })
        headers = {
            "x-ratelimit-limit": "5000",
            "x-ratelimit-remaining": str(self.remaining_rate_limit),
            "x-ratelimit-reset": "1724284800",
        }
        self.remaining_rate_limit -= 1

        if "issues/100/comments" in endpoint and method == "GET":
            return 200, [{"id": 1, "user": {"login": "dev1"}, "body": "Comment text"}], headers
        elif "issues/100/comments" in endpoint and method == "POST":
            return 201, {"id": 2, "body": data.get("body")}, headers
        elif "issues/100/labels" in endpoint and method == "POST":
            return 200, [{"name": l} for l in data.get("labels", [])], headers
        elif "issues/100" in endpoint and method == "PATCH":
            return 200, {"number": 100, "state": data.get("state")}, headers
        elif "issues/100" in endpoint and method == "GET":
            return 200, {"number": 100, "title": "Mock Issue", "state": "open", "user": {"login": "dev1"}}, headers
        elif "issues" in endpoint and method == "GET":
            return 200, [
                {"number": 100, "title": "Mock Issue 100", "user": {"login": "dev1"}},
                {"number": 101, "title": "PR to ignore", "pull_request": {}, "user": {"login": "pr_bot"}},
            ], headers

        return 404, {"message": "Not Found"}, headers


class TestGitHubRESTClient(unittest.TestCase):
    def setUp(self):
        self.mock_transport = MockTransport()
        self.client = GitHubRESTClient(token="mock_token_123", transport_mock=self.mock_transport)

    def test_list_open_issues_filters_prs(self):
        issues = self.client.list_open_issues()
        self.assertEqual(len(issues), 1)
        self.assertEqual(issues[0]["number"], 100)
        self.assertEqual(self.client.rate_limit_remaining, 4990)

    def test_get_issue_and_comments(self):
        issue = self.client.get_issue(100)
        self.assertEqual(issue["number"], 100)
        comments = self.client.list_issue_comments(100)
        self.assertEqual(len(comments), 1)
        self.assertEqual(comments[0]["user"]["login"], "dev1")

    def test_add_comment(self):
        res = self.client.add_comment(100, "Thank you for the detailed report.")
        self.assertEqual(res["body"], "Thank you for the detailed report.")

    def test_add_labels_and_close(self):
        labels = self.client.add_labels(100, ["triage:resolved", "db:mysql84"])
        self.assertIn("triage:resolved", labels)
        closed = self.client.close_issue(100, reason="completed")
        self.assertEqual(closed["state"], "closed")


if __name__ == "__main__":
    unittest.main()
