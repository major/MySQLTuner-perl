"""
Stateful Pagination and Ingestion Checkpoint Manager
"""

from __future__ import annotations

import json
import os
import time
from typing import Dict, List, Optional, Any, Callable


class PaginationCheckpointManager:
    DEFAULT_STATE_FILE = os.path.join(os.path.dirname(__file__), ".triage_state.json")

    def __init__(self, state_file_path: Optional[str] = None):
        self.state_file_path = state_file_path or self.DEFAULT_STATE_FILE
        self.state: Dict[str, Any] = {
            "last_sync_time": None,
            "last_processed_number": 0,
            "processed_issues": [],
            "graphql_end_cursor": None,
            "total_ingested": 0,
        }
        self.load_state()

    def load_state(self):
        if os.path.exists(self.state_file_path):
            try:
                with open(self.state_file_path, "r", encoding="utf-8") as f:
                    self.state = json.load(f)
            except Exception:
                pass

    def save_state(self):
        try:
            with open(self.state_file_path, "w", encoding="utf-8") as f:
                json.dump(self.state, f, indent=2)
        except Exception:
            pass

    def record_issue_processed(self, issue_number: int, end_cursor: Optional[str] = None):
        if issue_number not in self.state["processed_issues"]:
            self.state["processed_issues"].append(issue_number)
        self.state["last_processed_number"] = max(self.state.get("last_processed_number", 0), issue_number)
        self.state["last_sync_time"] = int(time.time())
        if end_cursor:
            self.state["graphql_end_cursor"] = end_cursor
        self.state["total_ingested"] = len(self.state["processed_issues"])
        self.save_state()

    def is_issue_already_processed(self, issue_number: int) -> bool:
        return issue_number in self.state.get("processed_issues", [])

    def paginate_all(
        self,
        fetch_page_fn: Callable[[int, int], List[Dict[str, Any]]],
        per_page: int = 25,
        max_total: int = 100,
        skip_already_processed: bool = False,
    ) -> List[Dict[str, Any]]:
        page = 1
        collected: List[Dict[str, Any]] = []

        while len(collected) < max_total:
            batch = fetch_page_fn(page, per_page)
            if not batch:
                break

            for item in batch:
                num = item.get("number")
                if skip_already_processed and num and self.is_issue_already_processed(num):
                    continue
                collected.append(item)
                if len(collected) >= max_total:
                    break

            if len(batch) < per_page:
                break
            page += 1

        return collected
