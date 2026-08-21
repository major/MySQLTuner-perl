"""
GitHub GraphQL API v4 Client for batch issue, timeline, and comment retrieval
"""

from __future__ import annotations

import json
import os
import urllib.request
import urllib.error
from typing import Dict, List, Optional, Any, Tuple


class GraphQLAPIError(Exception):
    def __init__(self, errors: List[Dict[str, Any]]):
        messages = [e.get("message", "Unknown GraphQL error") for e in errors]
        super().__init__(f"GraphQL Errors: {'; '.join(messages)}")
        self.errors = errors


class GitHubGraphQLClient:
    ENDPOINT = "https://api.github.com/graphql"

    ISSUE_BATCH_QUERY = """
    query GetOpenIssuesWithContext($owner: String!, $name: String!, $first: Int!, $after: String) {
      repository(owner: $owner, name: $name) {
        issues(first: $first, after: $after, states: OPEN, orderBy: {field: CREATED_AT, direction: DESC}) {
          totalCount
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            number
            title
            body
            state
            createdAt
            updatedAt
            author {
              login
            }
            labels(first: 10) {
              nodes {
                name
              }
            }
            comments(last: 10) {
              totalCount
              nodes {
                id
                body
                createdAt
                author {
                  login
                }
              }
            }
          }
        }
      }
      rateLimit {
        limit
        cost
        remaining
        resetAt
      }
    }
    """

    def __init__(self, token: Optional[str] = None, transport_mock=None):
        self.token = token or os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
        self.transport_mock = transport_mock
        self.rate_limit_remaining = 5000
        self.rate_limit_cost = 1

    def execute_query(self, query: str, variables: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        if self.transport_mock:
            return self.transport_mock.execute(query, variables)

        if not self.token:
            raise GraphQLAPIError([{"message": "Authentication token is required for GitHub GraphQL API v4"}])

        payload = {"query": query, "variables": variables or {}}
        req = urllib.request.Request(
            self.ENDPOINT,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Authorization": f"bearer {self.token}",
                "Content-Type": "application/json",
                "User-Agent": "MySQLTuner-GraphQLClient/1.0",
            },
            method="POST",
        )

        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                if "errors" in data and data["errors"]:
                    raise GraphQLAPIError(data["errors"])
                if "data" in data and "rateLimit" in data["data"]:
                    rl = data["data"]["rateLimit"]
                    self.rate_limit_remaining = rl.get("remaining", self.rate_limit_remaining)
                    self.rate_limit_cost = rl.get("cost", 1)
                return data.get("data", {})
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8") if e.fp else ""
            raise GraphQLAPIError([{"message": f"HTTP {e.code}: {raw}"}])

    def fetch_open_issues_batch(
        self, owner: str = "jmrenouard", name: str = "MySQLTuner-perl", count: int = 25, cursor: Optional[str] = None
    ) -> Tuple[List[Dict[str, Any]], bool, Optional[str]]:
        variables = {
            "owner": owner,
            "name": name,
            "first": count,
            "after": cursor,
        }
        res = self.execute_query(self.ISSUE_BATCH_QUERY, variables)
        repo_data = res.get("repository", {})
        issues_data = repo_data.get("issues", {})
        nodes = issues_data.get("nodes", [])
        page_info = issues_data.get("pageInfo", {})
        has_next = page_info.get("hasNextPage", False)
        end_cursor = page_info.get("endCursor")
        return nodes, has_next, end_cursor
