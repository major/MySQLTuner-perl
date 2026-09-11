"""
Unified Multi-Transport GitHub Ingestion Service
"""

from __future__ import annotations

import os
import logging
from typing import Dict, List, Optional, Any
from build.issue_triage.models import GitHubIssueRecord, GitHubComment, IssueAuthorType, IssueCategory, TriageStatus
from build.issue_triage.sanitizer import TextSanitizer
from build.issue_triage.github_rest_client import GitHubRESTClient
from build.issue_triage.github_graphql_client import GitHubGraphQLClient
from build.issue_triage.github_cli_wrapper import GitHubCLIWrapper
from build.issue_triage.offline_replay_engine import OfflineReplayEngine
from build.issue_triage.rate_limiter import AdaptiveRateLimiter
from build.issue_triage.pagination_manager import PaginationCheckpointManager

logger = logging.getLogger("issue_triage.ingest")


class GitHubIngestionService:
    MAINTAINER_USERNAME = "jmrenouard"

    def __init__(
        self,
        token: Optional[str] = None,
        repo: str = "jmrenouard/MySQLTuner-perl",
        offline_engine: Optional[OfflineReplayEngine] = None,
        state_file: Optional[str] = None,
    ):
        self.repo = repo
        self.token = token or GitHubRESTClient.discover_token()
        self.offline_engine = offline_engine
        self.rate_limiter = AdaptiveRateLimiter()
        self.pagination_mgr = PaginationCheckpointManager(state_file)

        # Clients
        self.rest_client = GitHubRESTClient(
            token=self.token,
            default_repo=self.repo,
            transport_mock=self.offline_engine.export_as_transport_mock() if self.offline_engine else None,
        )
        self.graphql_client = GitHubGraphQLClient(token=self.token)
        self.cli_wrapper = GitHubCLIWrapper(default_repo=self.repo)

    def classify_author(self, username: Optional[str]) -> IssueAuthorType:
        if not username:
            return IssueAuthorType.COMMUNITY_USER
        username_clean = username.strip().lower()
        if username_clean == self.MAINTAINER_USERNAME.lower():
            return IssueAuthorType.MAINTAINER
        if username_clean.endswith("[bot]") or username_clean in ["dependabot", "coderabbit", "github-actions"]:
            return IssueAuthorType.BOT
        return IssueAuthorType.COMMUNITY_USER

    def transform_raw_issue(self, raw: Dict[str, Any]) -> GitHubIssueRecord:
        num = raw.get("number", 0)
        title = raw.get("title", "")
        raw_author = ""
        if isinstance(raw.get("author"), dict):
            raw_author = raw["author"].get("login", "")
        elif isinstance(raw.get("user"), dict):
            raw_author = raw["user"].get("login", "")
        elif isinstance(raw.get("author"), str):
            raw_author = raw["author"]

        author_type = self.classify_author(raw_author)
        body = raw.get("body") or ""
        clean_body = TextSanitizer.normalize_text(body)
        clean_title = TextSanitizer.normalize_text(title)

        labels_list = []
        raw_labels = raw.get("labels", [])
        if isinstance(raw_labels, dict) and "nodes" in raw_labels:
            labels_list = [l.get("name") for l in raw_labels["nodes"] if l.get("name")]
        elif isinstance(raw_labels, list):
            for l in raw_labels:
                if isinstance(l, dict):
                    labels_list.append(l.get("name", ""))
                elif isinstance(l, str):
                    labels_list.append(l)

        # Transform comments
        comments_list: List[GitHubComment] = []
        raw_comments = raw.get("comments", [])
        comment_items = []
        if isinstance(raw_comments, dict) and "nodes" in raw_comments:
            comment_items = raw_comments["nodes"]
        elif isinstance(raw_comments, list):
            comment_items = raw_comments

        for c in comment_items:
            c_author = ""
            if isinstance(c.get("author"), dict):
                c_author = c["author"].get("login", "")
            elif isinstance(c.get("user"), dict):
                c_author = c["user"].get("login", "")
            elif isinstance(c.get("author"), str):
                c_author = c["author"]

            c_body = TextSanitizer.normalize_text(c.get("body", ""))
            comments_list.append(
                GitHubComment(
                    comment_id=c.get("id", 0),
                    author=c_author,
                    body=c_body,
                    created_at=c.get("createdAt") or c.get("created_at") or "",
                    is_maintainer=(self.classify_author(c_author) == IssueAuthorType.MAINTAINER),
                )
            )

        state = raw.get("state", "open").lower()
        triage_status = TriageStatus.MAINTAINER_HOLD if author_type == IssueAuthorType.MAINTAINER else TriageStatus.PENDING_INGESTION

        return GitHubIssueRecord(
            number=num,
            title=clean_title,
            author=raw_author,
            author_type=author_type,
            created_at=raw.get("createdAt") or raw.get("created_at") or "",
            updated_at=raw.get("updatedAt") or raw.get("updated_at") or "",
            state=state,
            body=clean_body,
            labels=labels_list,
            comments=comments_list,
            triage_status=triage_status,
            raw_payload=raw,
        )

    def fetch_open_issues(self, limit: int = 50) -> List[GitHubIssueRecord]:
        raw_issues: List[Dict[str, Any]] = []

        if self.offline_engine:
            raw_issues = self.offline_engine.list_issues(state="open")[:limit]
        elif self.token:
            try:
                # Attempt GraphQL batch
                owner, name = self.repo.split("/", 1) if "/" in self.repo else ("jmrenouard", "MySQLTuner-perl")
                nodes, _, _ = self.graphql_client.fetch_open_issues_batch(owner=owner, name=name, count=min(limit, 50))
                raw_issues = nodes
            except Exception as e:
                logger.warning(f"GraphQL fetch failed ({e}), falling back to REST client.")
                raw_issues = self.rest_client.list_open_issues(per_page=min(limit, 50))
        elif self.cli_wrapper.is_available():
            try:
                raw_issues = self.cli_wrapper.list_issues(limit=limit, state="open")
            except Exception as e:
                logger.warning(f"gh CLI fetch failed ({e}), falling back to REST client.")
                raw_issues = self.rest_client.list_open_issues(per_page=min(limit, 50))
        else:
            raw_issues = self.rest_client.list_open_issues(per_page=min(limit, 50))

        records = [self.transform_raw_issue(raw) for raw in raw_issues]
        for r in records:
            self.pagination_mgr.record_issue_processed(r.number)
        return records

    def fetch_single_issue(self, issue_number: int) -> Optional[GitHubIssueRecord]:
        raw_issue = None
        if self.offline_engine:
            raw_issue = self.offline_engine.get_issue(issue_number)
        else:
            try:
                raw_issue = self.rest_client.get_issue(issue_number)
            except Exception as e:
                logger.warning(f"REST fetch for issue #{issue_number} failed: {e}")

        if raw_issue:
            return self.transform_raw_issue(raw_issue)
        return None


GitHubIngestionFacade = GitHubIngestionService
