"""
Pre-Closing Invariant Checklist & Safety Protocol for MySQLTuner Issue Triage
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Dict, Tuple, Optional
from build.issue_triage.models import GitHubIssueRecord, IssueAuthorType
from build.issue_triage.sanitizer import TextSanitizer


@dataclass
class ChecklistResult:
    all_invariants_satisfied: bool
    failed_invariants: List[str] = field(default_factory=list)
    passed_invariants: List[str] = field(default_factory=list)


class PreClosingChecklist:
    @classmethod
    def audit_invariants(
        cls,
        issue: GitHubIssueRecord,
        response_text: str,
        commit_sha: str,
        attempt_close: bool = False,
    ) -> ChecklistResult:
        passed: List[str] = []
        failed: List[str] = []

        # Invariant 1: Author check
        if attempt_close and (
            issue.author_type == IssueAuthorType.MAINTAINER
            or issue.author.strip().lower() == "jmrenouard"
        ):
            failed.append("INVARIANT_AUTHOR_NON_MAINTAINER: Author is maintainer (@jmrenouard). Closure forbidden.")
        else:
            passed.append("INVARIANT_AUTHOR_NON_MAINTAINER")

        # Invariant 2 & 3: Test proofs
        if attempt_close:
            if not issue.test_proofs:
                failed.append("INVARIANT_TEST_PROOF_EXISTS: No test proof artifact attached.")
            else:
                if all(tp.syntax_valid for tp in issue.test_proofs):
                    passed.append("INVARIANT_SYNTAX_VALID")
                else:
                    failed.append("INVARIANT_SYNTAX_VALID: One or more test proofs have syntax errors.")

                if any(tp.execution_passed for tp in issue.test_proofs):
                    passed.append("INVARIANT_TEST_PASSING")
                else:
                    failed.append("INVARIANT_TEST_PASSING: No test proof passed execution successfully.")
        else:
            passed.append("INVARIANT_SYNTAX_VALID (N/A)")
            passed.append("INVARIANT_TEST_PASSING (N/A)")

        # Invariant 4: Doc links
        if issue.findings:
            if all(bool(f.official_doc_url and f.official_doc_url.startswith("http")) for f in issue.findings):
                passed.append("INVARIANT_DOC_LINK_PRESENT")
            else:
                failed.append("INVARIANT_DOC_LINK_PRESENT: One or more findings lack official documentation URLs.")
        else:
            passed.append("INVARIANT_DOC_LINK_PRESENT")

        # Invariant 5: Response quality
        if response_text and len(response_text) >= 50 and ("###" in response_text or "##" in response_text):
            passed.append("INVARIANT_RESPONSE_NON_EMPTY")
        else:
            failed.append("INVARIANT_RESPONSE_NON_EMPTY: Response is too short or missing structured Markdown headings.")

        # Invariant 6: Commit SHA
        if commit_sha and len(commit_sha) >= 4:
            passed.append("INVARIANT_COMMIT_PINNED")
        else:
            failed.append("INVARIANT_COMMIT_PINNED: Missing commit SHA.")

        # Invariant 7: Sanitization
        sanitized, redact_count = TextSanitizer.redact_secrets(response_text)
        if redact_count == 0 and sanitized == response_text:
            passed.append("INVARIANT_SANITIZATION_PASSED")
        else:
            failed.append("INVARIANT_SANITIZATION_PASSED: Response contains unmasked secrets/tokens.")

        all_ok = (len(failed) == 0)
        return ChecklistResult(
            all_invariants_satisfied=all_ok,
            failed_invariants=failed,
            passed_invariants=passed,
        )
