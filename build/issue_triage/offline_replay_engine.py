"""
Offline Replay & Mock Fixture Recording Engine
"""

from __future__ import annotations

import json
import os
from typing import Dict, List, Optional, Any, Tuple


class OfflineReplayEngine:
    DEFAULT_FIXTURES_PATH = os.path.join(os.path.dirname(__file__), "fixtures", "sample_issues.json")

    def __init__(self, fixtures_path: Optional[str] = None):
        self.fixtures_path = fixtures_path or self.DEFAULT_FIXTURES_PATH
        self.issues: Dict[int, Dict[str, Any]] = {}
        self.comments: Dict[int, List[Dict[str, Any]]] = {}
        self.actions_log: List[Dict[str, Any]] = []
        self._load_fixtures()

    def _load_fixtures(self):
        if os.path.exists(self.fixtures_path):
            with open(self.fixtures_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                for item in data:
                    num = item["number"]
                    self.issues[num] = item
                    self.comments[num] = item.get("comments", [])

    def get_issue(self, number: int) -> Optional[Dict[str, Any]]:
        return self.issues.get(number)

    def list_issues(self, state: str = "open") -> List[Dict[str, Any]]:
        return [issue for issue in self.issues.values() if issue.get("state") == state]

    def add_comment(self, number: int, author: str, body: str) -> Dict[str, Any]:
        comment = {
            "id": len(self.comments.get(number, [])) + 1,
            "author": author,
            "body": body,
            "created_at": "2026-08-22T00:00:00Z",
        }
        if number not in self.comments:
            self.comments[number] = []
        self.comments[number].append(comment)
        self.actions_log.append({"action": "comment", "number": number, "body": body})
        return comment

    def close_issue(self, number: int, reason: str = "completed") -> bool:
        if number in self.issues:
            self.issues[number]["state"] = "closed"
            self.issues[number]["state_reason"] = reason
            self.actions_log.append({"action": "close", "number": number, "reason": reason})
            return True
        return False

    def add_labels(self, number: int, labels: List[str]) -> List[str]:
        if number in self.issues:
            existing = set(self.issues[number].get("labels", []))
            existing.update(labels)
            self.issues[number]["labels"] = sorted(list(existing))
            self.actions_log.append({"action": "add_labels", "number": number, "labels": labels})
            return self.issues[number]["labels"]
        return []

    def export_as_transport_mock(self):
        parent = self

        class MockTransportWrapper:
            def request(self, endpoint: str, method: str = "GET", params=None, data=None):
                headers = {
                    "x-ratelimit-limit": "5000",
                    "x-ratelimit-remaining": "4999",
                    "x-ratelimit-reset": "1724284800",
                }
                if "/comments" in endpoint and method == "POST":
                    num = int(endpoint.split("/issues/")[1].split("/comments")[0])
                    res = parent.add_comment(num, "MySQLTunerBot", data.get("body", ""))
                    return 201, res, headers
                elif "/labels" in endpoint and method == "POST":
                    num = int(endpoint.split("/issues/")[1].split("/labels")[0])
                    res = parent.add_labels(num, data.get("labels", []))
                    return 200, [{"name": l} for l in res], headers
                elif "/issues/" in endpoint and method == "PATCH":
                    num = int(endpoint.split("/issues/")[1])
                    if data.get("state") == "closed":
                        parent.close_issue(num, data.get("state_reason", "completed"))
                    return 200, parent.get_issue(num), headers
                elif "/issues/" in endpoint and method == "GET":
                    num = int(endpoint.split("/issues/")[1])
                    issue = parent.get_issue(num)
                    if issue:
                        return 200, issue, headers
                    return 404, {"message": "Issue not found"}, headers
                elif "/issues" in endpoint and method == "GET":
                    return 200, parent.list_issues(state="open"), headers
                return 404, {"message": "Endpoint not found"}, headers

        return MockTransportWrapper()
