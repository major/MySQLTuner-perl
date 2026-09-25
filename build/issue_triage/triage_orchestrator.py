"""
Unified CLI Triage Orchestrator for MySQLTuner GitHub Issues
"""

from __future__ import annotations

import argparse
import logging
import os
import sys

# Ensure workspace root is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from typing import List, Dict, Any, Optional

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

logger = logging.getLogger("issue_triage.orchestrator")


class IssueTriageOrchestrator:
    def __init__(
        self,
        repo: str = "jmrenouard/MySQLTuner-perl",
        offline_mode: bool = False,
        dry_run: bool = True,
        output_dir: Optional[str] = None,
    ):
        self.repo = repo
        self.offline_mode = offline_mode
        self.dry_run = dry_run
        self.output_dir = output_dir or os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "..", "reports", "triage")
        )
        os.makedirs(self.output_dir, exist_ok=True)

        offline_eng = None
        if self.offline_mode:
            from build.issue_triage.offline_replay_engine import OfflineReplayEngine
            if "major" in self.repo.lower():
                major_fixtures = os.path.abspath(
                    os.path.join(os.path.dirname(__file__), "fixtures", "sample_issues_major.json")
                )
                offline_eng = OfflineReplayEngine(fixtures_path=major_fixtures)
            else:
                offline_eng = OfflineReplayEngine()

        self.ingest_facade = GitHubIngestionFacade(
            repo=self.repo,
            offline_engine=offline_eng,
        )
        self.diag_engine = DiagnosticEngine()
        self.test_gen = PerlTestGenerator()

    def process_issue(self, issue: GitHubIssueRecord) -> Dict[str, Any]:
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
        report_file = os.path.join(self.output_dir, f"issue_{issue.number}_report.md")
        with open(report_file, "w", encoding="utf-8") as f:
            f.write(report_md)

        # 6. Apply Actions if not dry-run
        actions_taken = []
        if not self.dry_run:
            if not checklist.all_invariants_satisfied:
                actions_taken.append(f"BLOCKED: Safety checklist failed: {checklist.failed_invariants}")
            else:
                # Add comment
                if self.ingest_facade.rest_client:
                    self.ingest_facade.rest_client.add_comment(issue.number, decision.response_markdown)
                    actions_taken.append("COMMENT_POSTED")

                    # Update labels
                    if decision.target_labels_to_add:
                        self.ingest_facade.rest_client.add_labels(issue.number, decision.target_labels_to_add)
                        actions_taken.append(f"LABELS_ADDED({','.join(decision.target_labels_to_add)})")

                    # Close issue if permitted
                    if decision.can_auto_close:
                        self.ingest_facade.rest_client.close_issue(issue.number)
                        actions_taken.append("ISSUE_CLOSED")
        else:
            actions_taken.append("DRY_RUN_SIMULATED")

        return {
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

    def run_all(self, limit: int = 50, issue_number: Optional[int] = None) -> List[Dict[str, Any]]:
        results: List[Dict[str, Any]] = []

        if issue_number:
            issue = self.ingest_facade.fetch_single_issue(issue_number)
            if issue:
                res = self.process_issue(issue)
                results.append(res)
        else:
            issues = self.ingest_facade.fetch_open_issues(limit=limit)
            for issue in issues:
                res = self.process_issue(issue)
                results.append(res)

        return results


def main() -> None:
    parser = argparse.ArgumentParser(description="MySQLTuner GitHub Issue Triage Orchestrator")
    parser.add_argument("--repo", default="jmrenouard/MySQLTuner-perl", help="Target GitHub repo")
    parser.add_argument("--issue", type=int, default=None, help="Target specific issue number")
    parser.add_argument("--limit", type=int, default=10, help="Max issues to process")
    parser.add_argument("--offline", action="store_true", help="Use offline replay fixtures")
    parser.add_argument("--live", dest="dry_run", action="store_false", help="Perform live GitHub API mutations")
    parser.add_argument("--sync-upstream", action="store_true", help="Sync local modifications to major/MySQLTuner-perl with jmrenouard assignment")
    parser.set_defaults(dry_run=True)

    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

    if args.sync_upstream:
        from build.issue_triage.upstream_syncer import UpstreamSyncer
        syncer = UpstreamSyncer(
            upstream_repo="major/MySQLTuner-perl",
            offline_mode=args.offline,
            dry_run=args.dry_run,
        )
        results = syncer.run_all_upstream(limit=args.limit, issue_number=args.issue)
        print("\n" + "=" * 80)
        print(f"UPSTREAM (major/MySQLTuner-perl) TRIAGE COMPLETE: Processed {len(results)} issues (DryRun={args.dry_run})")
        print("=" * 80)
        for r in results:
            print(f"#{r['issue_number']:<5} | @{r['author']:<15} | Status: {r['triage_status']:<15} | CloseAllowed: {str(r['can_auto_close']):<5} | Actions: {','.join(r['actions_taken'])}")
        return

    orchestrator = IssueTriageOrchestrator(
        repo=args.repo,
        offline_mode=args.offline,
        dry_run=args.dry_run,
    )

    results = orchestrator.run_all(limit=args.limit, issue_number=args.issue)
    print("\n" + "=" * 80)
    print(f"TRIAGE EXECUTION COMPLETE: Processed {len(results)} issues (Repo={args.repo}, DryRun={args.dry_run})")
    print("=" * 80)
    for r in results:
        print(f"#{r['issue_number']:<5} | @{r['author']:<15} | Status: {r['triage_status']:<15} | CloseAllowed: {str(r['can_auto_close']):<5} | Actions: {','.join(r['actions_taken'])}")


if __name__ == "__main__":
    main()
