"""
Roadmap and Milestone Synchronization Engine
"""

from __future__ import annotations

import os
import re
from typing import List, Dict, Tuple, Optional
from build.issue_triage.models import GitHubIssueRecord, TriageStatus


class RoadmapSyncEngine:
    DEFAULT_ROADMAP_PATH = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "..", "ROADMAP.md")
    )

    def __init__(self, roadmap_path: Optional[str] = None):
        self.roadmap_path = roadmap_path or self.DEFAULT_ROADMAP_PATH

    def sync_resolved_issues(
        self, resolved_issues: List[GitHubIssueRecord], dry_run: bool = True
    ) -> Tuple[int, str]:
        if not os.path.exists(self.roadmap_path):
            return 0, ""

        with open(self.roadmap_path, "r", encoding="utf-8") as f:
            content = f.read()

        updated_content = content
        synced_count = 0

        for issue in resolved_issues:
            issue_num_pattern = rf"- \[ \]\s+(.*?(?:#{issue.number}\b|Issue {issue.number}\b|[^\n\r]*{re.escape(issue.title[:30])}))"
            matches = list(re.finditer(issue_num_pattern, updated_content, re.IGNORECASE))
            if matches:
                synced_count += len(matches)
                updated_content = re.sub(
                    issue_num_pattern,
                    r"- [x] \1",
                    updated_content,
                    flags=re.IGNORECASE,
                )

        if not dry_run and synced_count > 0:
            with open(self.roadmap_path, "w", encoding="utf-8") as f:
                f.write(updated_content)

        return synced_count, updated_content
