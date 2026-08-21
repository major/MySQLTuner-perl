"""
GitHub REST API v3 Client with Token Management & Rate-Limit Tracking
"""

from __future__ import annotations

import json
import os
import urllib.request
import urllib.error
import urllib.parse
from typing import Dict, List, Optional, Any, Tuple
from build.issue_triage.models import GitHubIssueRecord, GitHubComment, IssueAuthorType


class GitHubAPIError(Exception):
    def __init__(self, status_code: int, message: str, rate_limit_remaining: Optional[int] = None):
        super().__init__(f"GitHub API Error [{status_code}]: {message} (Remaining: {rate_limit_remaining})")
        self.status_code = status_code
        self.message = message
        self.rate_limit_remaining = rate_limit_remaining


class GitHubRESTClient:
    BASE_URL = "https://api.github.com"

    @classmethod
    def discover_token(cls) -> Optional[str]:
        t = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
        if t:
            return t
        try:
            import subprocess
            import re
            url = subprocess.check_output(["git", "config", "--get", "remote.origin.url"], text=True).strip()
            m = re.search(r"https://([^:@]+)@github\.com", url)
            if m:
                return m.group(1)
        except Exception:
            pass
        return None

    def __init__(
        self,
        token: Optional[str] = None,
        default_repo: str = "jmrenouard/MySQLTuner-perl",
        transport_mock=None,
    ):
        self.token = token or self.discover_token()
        self.default_repo = default_repo
        self.transport_mock = transport_mock
        self.rate_limit_limit = 60
        self.rate_limit_remaining = 60
        self.rate_limit_reset = 0

    def _get_headers(self) -> Dict[str, str]:
        headers = {
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "MySQLTuner-IssueTriage/1.0 (automation-bot)",
        }
        if self.token:
            headers["Authorization"] = f"token {self.token}"
        return headers

    def _request(
        self,
        endpoint: str,
        method: str = "GET",
        params: Optional[Dict[str, Any]] = None,
        data: Optional[Dict[str, Any]] = None,
    ) -> Tuple[int, Any, Dict[str, str]]:
        if self.transport_mock:
            status, data, resp_headers = self.transport_mock.request(endpoint, method, params, data)
            if resp_headers:
                self._update_rate_limits(resp_headers)
            return status, data, resp_headers

        url = f"{self.BASE_URL}/{endpoint.lstrip('/')}"
        if params:
            query_str = urllib.parse.urlencode(params)
            url = f"{url}?{query_str}"

        body_bytes = None
        if data is not None:
            body_bytes = json.dumps(data).encode("utf-8")

        req = urllib.request.Request(
            url,
            data=body_bytes,
            headers=self._get_headers(),
            method=method,
        )

        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                status_code = resp.getcode()
                resp_headers = dict(resp.headers)
                raw_body = resp.read().decode("utf-8")
                parsed_body = json.loads(raw_body) if raw_body else {}
                self._update_rate_limits(resp_headers)
                return status_code, parsed_body, resp_headers
        except urllib.error.HTTPError as e:
            resp_headers = dict(e.headers)
            self._update_rate_limits(resp_headers)
            raw_err = e.read().decode("utf-8") if e.fp else ""
            try:
                err_json = json.loads(raw_err)
                err_msg = err_json.get("message", raw_err)
            except Exception:
                err_msg = raw_err or str(e)
            raise GitHubAPIError(e.code, err_msg, self.rate_limit_remaining)
        except urllib.error.URLError as e:
            raise GitHubAPIError(0, f"Network connection error: {e.reason}")

    def _update_rate_limits(self, headers: Dict[str, str]):
        for k, v in headers.items():
            if k.lower() == "x-ratelimit-limit":
                self.rate_limit_limit = int(v)
            elif k.lower() == "x-ratelimit-remaining":
                self.rate_limit_remaining = int(v)
            elif k.lower() == "x-ratelimit-reset":
                self.rate_limit_reset = int(v)

    def get_issue(self, issue_number: int, repo: Optional[str] = None) -> Dict[str, Any]:
        target_repo = repo or self.default_repo
        status, data, _ = self._request(f"repos/{target_repo}/issues/{issue_number}")
        return data

    def list_open_issues(
        self,
        repo: Optional[str] = None,
        labels: Optional[str] = None,
        per_page: int = 30,
        page: int = 1,
    ) -> List[Dict[str, Any]]:
        target_repo = repo or self.default_repo
        params = {
            "state": "open",
            "per_page": per_page,
            "page": page,
        }
        if labels:
            params["labels"] = labels
        status, data, _ = self._request(f"repos/{target_repo}/issues", params=params)
        # Filter out Pull Requests (GitHub issues endpoint returns both issues and PRs)
        issues = [item for item in data if "pull_request" not in item]
        return issues

    def list_issue_comments(self, issue_number: int, repo: Optional[str] = None) -> List[Dict[str, Any]]:
        target_repo = repo or self.default_repo
        status, data, _ = self._request(f"repos/{target_repo}/issues/{issue_number}/comments")
        return data

    def add_comment(self, issue_number: int, body: str, repo: Optional[str] = None) -> Dict[str, Any]:
        target_repo = repo or self.default_repo
        status, data, _ = self._request(
            f"repos/{target_repo}/issues/{issue_number}/comments",
            method="POST",
            data={"body": body},
        )
        return data

    def add_labels(self, issue_number: int, labels: List[str], repo: Optional[str] = None) -> List[str]:
        target_repo = repo or self.default_repo
        status, data, _ = self._request(
            f"repos/{target_repo}/issues/{issue_number}/labels",
            method="POST",
            data={"labels": labels},
        )
        return [l.get("name") if isinstance(l, dict) else l for l in data]

    def remove_label(self, issue_number: int, label: str, repo: Optional[str] = None) -> bool:
        target_repo = repo or self.default_repo
        try:
            status, _, _ = self._request(
                f"repos/{target_repo}/issues/{issue_number}/labels/{urllib.parse.quote(label)}",
                method="DELETE",
            )
            return status in [200, 204]
        except GitHubAPIError as e:
            if e.status_code == 404:
                return True
            raise

    def close_issue(
        self,
        issue_number: int,
        reason: str = "completed",
        repo: Optional[str] = None,
    ) -> Dict[str, Any]:
        target_repo = repo or self.default_repo
        status, data, _ = self._request(
            f"repos/{target_repo}/issues/{issue_number}",
            method="PATCH",
            data={"state": "closed", "state_reason": reason},
        )
        return data
