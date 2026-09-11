"""
GitHub CLI (gh) subprocess wrapper and bridge
"""

from __future__ import annotations

import json
import shutil
import subprocess
from typing import Dict, List, Optional, Any, Tuple


class GitHubCLIError(Exception):
    def __init__(self, command: List[str], returncode: int, stderr: str):
        super().__init__(f"GitHub CLI failed [{returncode}]: {' '.join(command)} -> {stderr}")
        self.command = command
        self.returncode = returncode
        self.stderr = stderr


class GitHubCLIWrapper:
    def __init__(self, binary_path: Optional[str] = None, default_repo: str = "jmrenouard/MySQLTuner-perl"):
        self.binary_path = binary_path or shutil.which("gh")
        self.default_repo = default_repo

    def is_available(self) -> bool:
        return bool(self.binary_path)

    def _run_gh(self, args: List[str], timeout: int = 20) -> Tuple[int, str, str]:
        if not self.is_available():
            raise GitHubCLIError(args, -1, "GitHub CLI ('gh') binary not found in PATH.")

        cmd = [self.binary_path] + args
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            stdout, stderr = proc.communicate(timeout=timeout)
            return proc.returncode, stdout.strip(), stderr.strip()
        except subprocess.TimeoutExpired:
            proc.kill()
            raise GitHubCLIError(cmd, -2, f"Command timed out after {timeout} seconds")

    def list_issues(self, repo: Optional[str] = None, limit: int = 30, state: str = "open") -> List[Dict[str, Any]]:
        target_repo = repo or self.default_repo
        args = [
            "issue",
            "list",
            "--repo",
            target_repo,
            "--state",
            state,
            "--limit",
            str(limit),
            "--json",
            "number,title,author,labels,createdAt,updatedAt,body,state",
        ]
        code, stdout, stderr = self._run_gh(args)
        if code != 0:
            raise GitHubCLIError(args, code, stderr)
        return json.loads(stdout) if stdout else []

    def view_issue(self, issue_number: int, repo: Optional[str] = None) -> Dict[str, Any]:
        target_repo = repo or self.default_repo
        args = [
            "issue",
            "view",
            str(issue_number),
            "--repo",
            target_repo,
            "--json",
            "number,title,author,labels,createdAt,updatedAt,body,state,comments",
        ]
        code, stdout, stderr = self._run_gh(args)
        if code != 0:
            raise GitHubCLIError(args, code, stderr)
        return json.loads(stdout) if stdout else {}

    def comment_issue(self, issue_number: int, body: str, repo: Optional[str] = None) -> str:
        target_repo = repo or self.default_repo
        args = [
            "issue",
            "comment",
            str(issue_number),
            "--repo",
            target_repo,
            "--body",
            body,
        ]
        code, stdout, stderr = self._run_gh(args)
        if code != 0:
            raise GitHubCLIError(args, code, stderr)
        return stdout

    def close_issue(self, issue_number: int, reason: str = "completed", repo: Optional[str] = None) -> str:
        target_repo = repo or self.default_repo
        args = [
            "issue",
            "close",
            str(issue_number),
            "--repo",
            target_repo,
            "--reason",
            reason,
        ]
        code, stdout, stderr = self._run_gh(args)
        if code != 0:
            raise GitHubCLIError(args, code, stderr)
        return stdout
