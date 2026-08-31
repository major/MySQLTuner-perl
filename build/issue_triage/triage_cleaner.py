"""
Artifact Rotation and Triage Retention Cleaner
"""

from __future__ import annotations

import os
import shutil
from typing import List, Optional


class TriageCleaner:
    @classmethod
    def clean_reports_directory(cls, reports_dir: str, keep_count: int = 10) -> int:
        if not os.path.exists(reports_dir):
            return 0

        files = []
        for f in os.listdir(reports_dir):
            full_p = os.path.join(reports_dir, f)
            if os.path.isfile(full_p) and f.startswith("issue_") and f.endswith("_report.md"):
                files.append((os.path.getmtime(full_p), full_p))

        # Sort by mtime descending (most recent first)
        files.sort(key=lambda x: x[0], reverse=True)
        deleted = 0
        for _, path_to_remove in files[keep_count:]:
            try:
                os.remove(path_to_remove)
                deleted += 1
            except OSError:
                pass

        return deleted

    @classmethod
    def clean_orphan_test_files(cls, tests_dir: str, active_issue_numbers: List[int]) -> int:
        if not os.path.exists(tests_dir):
            return 0

        deleted = 0
        for f in os.listdir(tests_dir):
            if f.startswith("test_issue_") and f.endswith(".t"):
                # Extract number
                num_str = f.replace("test_issue_", "").replace(".t", "")
                if num_str.isdigit():
                    num = int(num_str)
                    if num not in active_issue_numbers:
                        full_p = os.path.join(tests_dir, f)
                        try:
                            os.remove(full_p)
                            deleted += 1
                        except OSError:
                            pass
        return deleted
