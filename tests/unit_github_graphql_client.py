"""
Unit tests for build.issue_triage.github_graphql_client
"""

import unittest
from build.issue_triage.github_graphql_client import GitHubGraphQLClient, GraphQLAPIError


class MockGraphQLTransport:
    def execute(self, query, variables):
        if "error_trigger" in (variables or {}):
            raise GraphQLAPIError([{"message": "Query failed intentionally"}])

        return {
            "repository": {
                "issues": {
                    "totalCount": 2,
                    "pageInfo": {
                        "hasNextPage": False,
                        "endCursor": "cursor_xyz",
                    },
                    "nodes": [
                        {
                            "number": 201,
                            "title": "GraphQL parsed issue",
                            "body": "innodb_buffer_pool_size check",
                            "state": "OPEN",
                            "createdAt": "2026-08-22T00:00:00Z",
                            "updatedAt": "2026-08-22T00:00:00Z",
                            "author": {"login": "dev_user"},
                            "labels": {"nodes": [{"name": "bug"}]},
                            "comments": {
                                "totalCount": 1,
                                "nodes": [{"id": 1, "body": "Comment text", "author": {"login": "jmrenouard"}}],
                            },
                        }
                    ],
                }
            },
            "rateLimit": {"limit": 5000, "cost": 1, "remaining": 4995, "resetAt": "2026-08-22T01:00:00Z"},
        }


class TestGitHubGraphQLClient(unittest.TestCase):
    def setUp(self):
        self.mock_transport = MockGraphQLTransport()
        self.client = GitHubGraphQLClient(token="mock_token", transport_mock=self.mock_transport)

    def test_fetch_open_issues_batch(self):
        nodes, has_next, cursor = self.client.fetch_open_issues_batch(count=10)
        self.assertEqual(len(nodes), 1)
        self.assertEqual(nodes[0]["number"], 201)
        self.assertEqual(nodes[0]["author"]["login"], "dev_user")
        self.assertFalse(has_next)
        self.assertEqual(cursor, "cursor_xyz")

    def test_error_handling(self):
        with self.assertRaises(GraphQLAPIError):
            self.client.execute_query("query { fail }", {"error_trigger": True})


if __name__ == "__main__":
    unittest.main()
