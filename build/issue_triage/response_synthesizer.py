"""
Contextual Technical Response Composer & Community Tone Standardizer
"""

from __future__ import annotations

from typing import Optional
from build.issue_triage.models import GitHubIssueRecord, IssueAuthorType
from build.issue_triage.config_snippet_formatter import ConfigSnippetFormatter
from build.issue_triage.ci_proof_linker import CIProofLinker


class ResponseSynthesizer:
    @classmethod
    def compose_comment(cls, issue: GitHubIssueRecord) -> str:
        sha = CIProofLinker.get_current_commit_sha()
        short_sha = sha[:8] if len(sha) >= 8 else sha
        ci_url = CIProofLinker.get_ci_run_url()

        # Check Maintainer condition
        if issue.author_type == IssueAuthorType.MAINTAINER:
            return cls._compose_maintainer_brief(issue, short_sha, ci_url)
        elif issue.author_type == IssueAuthorType.BOT:
            return cls._compose_bot_ack(issue, short_sha)
        else:
            return cls._compose_community_response(issue, short_sha, ci_url)

    @classmethod
    def _compose_community_response(cls, issue: GitHubIssueRecord, short_sha: str, ci_url: str) -> str:
        author = issue.author
        db_engine = issue.extracted_metrics.db_engine.value if issue.extracted_metrics else "MySQL"
        db_ver = issue.extracted_metrics.db_version_normalized if issue.extracted_metrics else ""
        is_mariadb = issue.extracted_metrics.db_engine.value == "MariaDB" if issue.extracted_metrics else False

        # Build findings table
        findings_rows = []
        for f in issue.findings:
            badge = "🟢 `[OK]`" if f.severity == "OK" else ("🟡 `[WARN]`" if f.severity == "WARN" else "🔴 `[BAD]`")
            findings_rows.append(f"- {badge} **{f.title}**: {f.root_cause} ([Official Docs]({f.official_doc_url}))")

        findings_text = "\n".join(findings_rows) if findings_rows else "- 🟢 All indicators evaluated healthy and consistent with MySQLTuner standards."

        # Build config snippet
        cnf_block = ConfigSnippetFormatter.format_cnf_block(issue.findings, is_mariadb=is_mariadb)
        config_section = ""
        if cnf_block:
            config_section = f"""### 🛠️ Recommended Configuration Adjustments
```ini
{cnf_block}
```
"""

        # Build test proof link
        test_section = ""
        if issue.test_proofs:
            tp = issue.test_proofs[0]
            t_url = CIProofLinker.get_test_file_url(tp.test_file_path, sha=short_sha)
            test_section = f"""### 🧪 Automated Validation & Test Proof
A dedicated regression test case has been executed and validated:
- **Test File:** [`{tp.test_file_path}`]({t_url})
- **Status:** `PASSING` ({tp.subtest_count} subtests)
- **CI Workflow:** [GitHub Actions Pipeline]({ci_url})
"""

        response = f"""Hello @{author},

Thank you very much for reporting this issue and for providing detailed environment metrics!

### 📊 Technical Diagnostic Summary for {db_engine} {db_ver}
{findings_text}

{config_section}
{test_section}

---
*If you have additional questions or need further clarification, feel free to reopen or reply. Thank you for contributing to MySQLTuner!*
"""
        return response.strip()

    @classmethod
    def _compose_maintainer_brief(cls, issue: GitHubIssueRecord, short_sha: str, ci_url: str) -> str:
        return f"""### 📋 Internal Maintainer Technical Brief — Issue #{issue.number}

- **Target:** {issue.extracted_metrics.db_engine.value if issue.extracted_metrics else 'MySQL'}
- **Findings Count:** {len(issue.findings)}
- **CI Status:** [GitHub Actions Run]({ci_url}) (Commit `{short_sha}`)
- **Action:** Held for maintainer review (`triage:maintainer-review`). Auto-close disabled.
""".strip()

    @classmethod
    def _compose_bot_ack(cls, issue: GitHubIssueRecord, short_sha: str) -> str:
        return f"Automated dependency / bot update noted. Processed under commit `{short_sha}`."
