"""
Reproducibility & Verification Report Generator
"""

from __future__ import annotations

from typing import Dict, Any, Optional
from build.issue_triage.models import GitHubIssueRecord
from build.issue_triage.ci_proof_linker import CIProofLinker


class ReproducibilityReporter:
    @classmethod
    def generate_markdown_report(cls, issue: GitHubIssueRecord) -> str:
        sha = CIProofLinker.get_current_commit_sha()
        ci_url = CIProofLinker.get_ci_run_url()
        
        findings_rows = []
        for f in issue.findings:
            badge = "🟢 OK" if f.severity == "OK" else ("🟡 WARN" if f.severity == "WARN" else "🔴 BAD")
            findings_rows.append(
                f"| `{f.rule_id}` | {badge} | **{f.title}** | {f.root_cause} | [{f.rule_id} Docs]({f.official_doc_url}) |"
            )

        findings_table = (
            "| Rule ID | Severity | Diagnostic Finding | Root Cause Analysis | Documentation |\n"
            "| :--- | :--- | :--- | :--- | :--- |\n" + "\n".join(findings_rows)
            if findings_rows
            else "_No diagnostic anomalies detected._"
        )

        test_proof_section = ""
        if issue.test_proofs:
            proof = issue.test_proofs[0]
            test_url = CIProofLinker.get_test_file_url(proof.test_file_path, sha=sha)
            status_badge = "✅ PASSING" if proof.execution_passed else "❌ FAILED"
            test_proof_section = f"""
### 🧪 Automated Test Proof & Verification
- **Test File:** [`{proof.test_file_path}`]({test_url})
- **Execution Status:** {status_badge} ({proof.subtest_count} subtests)
- **Reproduce Command:**
```bash
{proof.reproduce_command}
```
<details>
<summary><b>Test Execution Log Excerpt</b></summary>

```text
{proof.output_log_excerpt}
```
</details>
"""

        report = f"""## 🔍 MySQLTuner Autonomous Diagnostic & Verification Report — Issue #{issue.number}

- **Issue Title:** {issue.title}
- **Author:** @{issue.author} (`{issue.author_type.value}`)
- **Target DBMS Engine:** {issue.extracted_metrics.db_engine.value if issue.extracted_metrics else 'MySQL'} {issue.extracted_metrics.db_version_normalized if issue.extracted_metrics else ''}
- **Triage Status:** `{issue.triage_status.value}`
- **Verification Commit:** [`{sha[:8]}`]({CIProofLinker.get_commit_url(sha=sha)})
- **Continuous Integration Pipeline:** [GitHub Actions Run]({ci_url})

---

### 📊 Diagnostic Findings & Technical Analysis

{findings_table}

{test_proof_section}

---
*Report generated automatically by MySQLTuner Autonomous Issue Triage System.*
"""
        return report
