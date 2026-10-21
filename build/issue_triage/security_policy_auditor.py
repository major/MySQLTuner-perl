"""
DevSecOps Compliance & Least-Privilege Security Policy Auditor
"""

from __future__ import annotations

import os
import re
from typing import List, Dict, Tuple, Optional


class SecurityPolicyAuditor:
    DANGEROUS_PERMISSIONS = ["write-all", "admin:write", "repo:admin"]

    @classmethod
    def audit_github_workflow_permissions(cls, workflow_yaml_path: str) -> Tuple[bool, List[str]]:
        if not os.path.exists(workflow_yaml_path):
            return False, ["Workflow file does not exist"]

        with open(workflow_yaml_path, "r", encoding="utf-8") as f:
            content = f.read()

        issues = []
        for danger in cls.DANGEROUS_PERMISSIONS:
            if danger in content:
                issues.append(f"Excessive permission detected: {danger}")

        if "permissions:" not in content:
            issues.append("Workflow lacks explicit permissions block (defaults to unrestricted)")

        # Verify minimal required permissions
        if "issues: write" not in content and "issues: read" not in content:
            issues.append("Workflow missing required issue permission")

        passed = (len(issues) == 0)
        return passed, issues

    @classmethod
    def audit_state_and_report_hygiene(cls, file_path: str) -> Tuple[bool, List[str]]:
        if not os.path.exists(file_path):
            return True, []

        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

        issues = []
        token_patterns = [
            (r"ghp_[a-zA-Z0-9]{36}", "GitHub Personal Access Token"),
            (r"AKIA[0-9A-Z]{16}", "AWS Access Key ID"),
            (r"-----BEGIN PRIVATE KEY-----", "Private Key Header"),
        ]

        for pat, label in token_patterns:
            if re.search(pat, content):
                issues.append(f"Unmasked secret found in {os.path.basename(file_path)}: {label}")

        passed = (len(issues) == 0)
        return passed, issues
