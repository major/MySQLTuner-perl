"""
Upstream Repository Synchronization & Triage Module for major/MySQLTuner-perl
"""

from __future__ import annotations

import os
import re
import json
import logging
from typing import List, Dict, Any, Optional, Tuple

from build.issue_triage.models import (
    GitHubIssueRecord,
    IssueAuthorType,
    TriageStatus,
    GovernanceDecision,
)
from build.issue_triage.github_ingest import GitHubIngestionFacade
from build.issue_triage.diagnostic_engine import DiagnosticEngine
from build.issue_triage.test_generator import PerlTestGenerator
from build.issue_triage.ci_proof_linker import CIProofLinker
from build.issue_triage.response_synthesizer import ResponseSynthesizer
from build.issue_triage.pre_closing_checklist import PreClosingChecklist
from build.issue_triage.closing_governance import ClosingGovernanceEngine
from build.issue_triage.reproducibility_reporter import ReproducibilityReporter
from build.issue_triage.offline_replay_engine import OfflineReplayEngine

logger = logging.getLogger("issue_triage.upstream_syncer")


class UpstreamSyncer:
    UPSTREAM_REPO = "major/MySQLTuner-perl"
    DOWNSTREAM_REPO = "jmrenouard/MySQLTuner-perl"
    MAINTAINER_ASSIGNEE = "jmrenouard"

    CATEGORY_TAG_MAP = {
        "feat": ["enhancement", "feature"],
        "fix": ["bug", "fix"],
        "docs": ["documentation"],
        "perf": ["performance"],
        "test": ["testing"],
        "ci": ["maintenance"],
        "chore": ["maintenance"],
    }

    def __init__(
        self,
        upstream_repo: str = "major/MySQLTuner-perl",
        downstream_repo: str = "jmrenouard/MySQLTuner-perl",
        offline_mode: bool = False,
        dry_run: bool = True,
        output_dir: Optional[str] = None,
    ):
        self.upstream_repo = upstream_repo
        self.downstream_repo = downstream_repo
        self.offline_mode = offline_mode
        self.dry_run = dry_run
        self.output_dir = output_dir or os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "..", "reports", "upstream_triage")
        )
        os.makedirs(self.output_dir, exist_ok=True)

        offline_eng = None
        if self.offline_mode:
            major_fixtures = os.path.abspath(
                os.path.join(os.path.dirname(__file__), "fixtures", "sample_issues_major.json")
            )
            offline_eng = OfflineReplayEngine(fixtures_path=major_fixtures)

        self.ingest_facade = GitHubIngestionFacade(
            repo=self.upstream_repo,
            offline_engine=offline_eng,
        )
        self.diag_engine = DiagnosticEngine()
        self.test_gen = PerlTestGenerator()

    @classmethod
    def determine_tags_for_change(cls, commit_type: str, scope: Optional[str] = None) -> List[str]:
        tags = list(cls.CATEGORY_TAG_MAP.get(commit_type.lower(), ["maintenance"]))
        if scope:
            scope_clean = scope.lower().replace(" ", "")
            if "mysql" in scope_clean or "mariadb" in scope_clean or "percona" in scope_clean:
                tags.append(f"db:{scope_clean}")
            elif "cve" in scope_clean or "sec" in scope_clean:
                tags.append("security")
            elif "docker" in scope_clean or "container" in scope_clean:
                tags.append("container")
        return sorted(list(set(tags)))

    def format_upstream_issue_payload(
        self,
        title: str,
        description: str,
        commit_type: str = "feat",
        scope: Optional[str] = None,
        test_file_path: Optional[str] = None,
    ) -> Dict[str, Any]:
        tags = self.determine_tags_for_change(commit_type, scope)
        sha = CIProofLinker.get_current_commit_sha()
        short_sha = sha[:8] if len(sha) >= 8 else sha
        commit_url = CIProofLinker.get_commit_url(repo=self.downstream_repo, sha=sha)

        proof_snippet = ""
        if test_file_path:
            test_url = CIProofLinker.get_test_file_url(test_file_path, repo=self.downstream_repo, sha=sha)
            proof_snippet = f"\n\n### 🧪 Test & Validation Proof\nValidated in downstream repository: [`{test_file_path}`]({test_url})"

        body = f"""## 📋 Synchronized Update from {self.DOWNSTREAM_REPO}

**Modification Summary:**
{description}

**Downstream Commit:** [`{short_sha}`]({commit_url})
**Assignee:** @{self.MAINTAINER_ASSIGNEE}{proof_snippet}

---
*Synchronized automatically via MySQLTuner Autonomous Upstream Sync Engine.*
"""
        return {
            "title": title,
            "body": body.strip(),
            "assignees": [self.MAINTAINER_ASSIGNEE],
            "labels": tags,
        }

    def triage_upstream_issue(self, issue: GitHubIssueRecord) -> Dict[str, Any]:
        issue.repo = self.upstream_repo
        
        # 1. Run Diagnostic Engine
        analyzed_issue = self.diag_engine.analyze_issue(issue)

        # 2. Generate and verify Perl test proof
        proof = self.test_gen.write_and_verify_test(analyzed_issue)
        analyzed_issue.test_proofs = [proof]

        # 3. Formulate Governance Decision
        decision = ClosingGovernanceEngine.evaluate(analyzed_issue)

        # 4. Audit Safety Invariants
        commit_sha = CIProofLinker.get_current_commit_sha()
        checklist = PreClosingChecklist.audit_invariants(
            issue=analyzed_issue,
            response_text=decision.response_markdown,
            commit_sha=commit_sha,
            attempt_close=decision.can_auto_close,
        )

        # 5. Generate Markdown Report
        report_md = ReproducibilityReporter.generate_markdown_report(analyzed_issue)
        report_file = os.path.join(self.output_dir, f"major_issue_{issue.number}_report.md")
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(report_md)

        actions_taken = []
        if not self.dry_run:
            if not checklist.all_invariants_satisfied:
                actions_taken.append(f"BLOCKED: Safety checklist failed: {checklist.failed_invariants}")
            else:
                if self.ingest_facade.rest_client:
                    self.ingest_facade.rest_client.add_comment(issue.number, decision.response_markdown)
                    actions_taken.append("UPSTREAM_COMMENT_POSTED")
                    if decision.target_labels_to_add:
                        self.ingest_facade.rest_client.add_labels(issue.number, decision.target_labels_to_add)
                        actions_taken.append(f"UPSTREAM_LABELS_ADDED({','.join(decision.target_labels_to_add)})")
                    if decision.can_auto_close:
                        self.ingest_facade.rest_client.close_issue(issue.number)
                        actions_taken.append("UPSTREAM_ISSUE_CLOSED")
        else:
            actions_taken.append("DRY_RUN_UPSTREAM_SIMULATED")

        return {
            "repo": self.upstream_repo,
            "issue_number": issue.number,
            "title": issue.title,
            "author": issue.author,
            "author_type": issue.author_type.value,
            "triage_status": analyzed_issue.triage_status.value,
            "can_auto_close": decision.can_auto_close,
            "invariants_ok": checklist.all_invariants_satisfied,
            "actions_taken": actions_taken,
            "report_file": report_file,
        }

    def run_all_upstream(self, limit: int = 50, issue_number: Optional[int] = None) -> List[Dict[str, Any]]:
        results: List[Dict[str, Any]] = []
        if issue_number:
            issue = self.ingest_facade.fetch_single_issue(issue_number)
            if issue:
                results.append(self.triage_upstream_issue(issue))
        else:
            issues = self.ingest_facade.fetch_open_issues(limit=limit)
            for issue in issues:
                results.append(self.triage_upstream_issue(issue))
        return results
