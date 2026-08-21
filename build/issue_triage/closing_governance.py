"""
Closing Governance & Maintainer Shield Engine
"""

from __future__ import annotations

from typing import List, Dict, Any, Optional
from build.issue_triage.models import (
    GitHubIssueRecord,
    GovernanceDecision,
    IssueAuthorType,
    TriageStatus,
)
from build.issue_triage.response_synthesizer import ResponseSynthesizer


class ClosingGovernanceEngine:
    MAINTAINER_USERNAME = "jmrenouard"

    @classmethod
    def evaluate(cls, issue: GitHubIssueRecord) -> GovernanceDecision:
        author_clean = issue.author.strip().lower()
        is_maintainer = (author_clean == cls.MAINTAINER_USERNAME.lower())
        response_md = ResponseSynthesizer.compose_comment(issue)

        labels_to_add: List[str] = []
        labels_to_remove: List[str] = []

        # Add DB version label if available
        if issue.extracted_metrics and issue.extracted_metrics.db_engine:
            eng = issue.extracted_metrics.db_engine.value.lower().replace(" ", "")
            ver = issue.extracted_metrics.db_version_normalized or ""
            major_minor = ver.rsplit(".", 1)[0] if "." in ver else ver
            if major_minor:
                labels_to_add.append(f"db:{eng}{major_minor.replace('.', '')}")

        if is_maintainer:
            labels_to_add.append("triage:maintainer-review")
            return GovernanceDecision(
                author=issue.author,
                author_type=IssueAuthorType.MAINTAINER,
                can_auto_close=False,
                close_action_blocked_reason="Author is project maintainer (@jmrenouard). Automated issue closure is strictly prohibited by governance rules.",
                target_labels_to_add=sorted(list(set(labels_to_add))),
                target_labels_to_remove=labels_to_remove,
                response_markdown=response_md,
                closing_comment=None,
            )

        # Check community issue readiness
        has_passing_test = any(tp.execution_passed for tp in issue.test_proofs) if issue.test_proofs else False
        is_diagnosed = issue.triage_status in [TriageStatus.DIAGNOSED, TriageStatus.VERIFIED_ON_MASTER]

        if is_diagnosed and has_passing_test:
            labels_to_add.append("triage:resolved")
            labels_to_remove.append("triage:needs-info")
            return GovernanceDecision(
                author=issue.author,
                author_type=issue.author_type,
                can_auto_close=True,
                close_action_blocked_reason=None,
                target_labels_to_add=sorted(list(set(labels_to_add))),
                target_labels_to_remove=labels_to_remove,
                response_markdown=response_md,
                closing_comment="Resolved automatically with validated technical proof and test case.",
            )
        else:
            labels_to_add.append("triage:in-progress")
            return GovernanceDecision(
                author=issue.author,
                author_type=issue.author_type,
                can_auto_close=False,
                close_action_blocked_reason="Issue requires additional code patch or further community reproduction data.",
                target_labels_to_add=sorted(list(set(labels_to_add))),
                target_labels_to_remove=labels_to_remove,
                response_markdown=response_md,
                closing_comment=None,
            )
