"""
CI Proof Linker & Artifact Reference Generator
"""

from __future__ import annotations

import os
import subprocess
from typing import Optional, Dict


class CIProofLinker:
    DEFAULT_REPO = "jmrenouard/MySQLTuner-perl"

    @classmethod
    def get_current_commit_sha(cls) -> str:
        # Check environment variable from GitHub Actions
        env_sha = os.environ.get("GITHUB_SHA")
        if env_sha:
            return env_sha.strip()

        # Fallback to local git rev-parse HEAD
        try:
            res = subprocess.run(
                ["git", "rev-parse", "HEAD"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            if res.returncode == 0 and res.stdout.strip():
                return res.stdout.strip()
        except Exception:
            pass

        return "master"

    @classmethod
    def get_test_file_url(cls, test_relative_path: str, repo: Optional[str] = None, sha: Optional[str] = None) -> str:
        target_repo = repo or cls.DEFAULT_REPO
        target_sha = sha or cls.get_current_commit_sha()
        clean_path = test_relative_path.lstrip("/")
        return f"https://github.com/{target_repo}/blob/{target_sha}/{clean_path}"

    @classmethod
    def get_ci_run_url(cls, repo: Optional[str] = None, run_id: Optional[str] = None) -> str:
        target_repo = repo or cls.DEFAULT_REPO
        env_run = run_id or os.environ.get("GITHUB_RUN_ID")
        if env_run:
            return f"https://github.com/{target_repo}/actions/runs/{env_run}"
        return f"https://github.com/{target_repo}/actions"

    @classmethod
    def get_commit_url(cls, repo: Optional[str] = None, sha: Optional[str] = None) -> str:
        target_repo = repo or cls.DEFAULT_REPO
        target_sha = sha or cls.get_current_commit_sha()
        return f"https://github.com/{target_repo}/commit/{target_sha}"
