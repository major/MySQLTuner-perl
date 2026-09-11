"""
Consolidated Triage Audit & Metrics Exporter (JSON & Markdown Dashboard)
"""

from __future__ import annotations

import json
import os
import time
from typing import List, Dict, Any, Optional
from build.issue_triage.models import GitHubIssueRecord, IssueAuthorType, TriageStatus


class TriageAuditExporter:
    @classmethod
    def export_audit(
        cls,
        processed_issues: List[Dict[str, Any]],
        output_dir: str,
    ) -> Dict[str, str]:
        os.makedirs(output_dir, exist_ok=True)

        total = len(processed_issues)
        maintainer_count = sum(1 for i in processed_issues if i.get("author_type") == "maintainer")
        community_count = sum(1 for i in processed_issues if i.get("author_type") == "community")
        closed_count = sum(1 for i in processed_issues if i.get("can_auto_close"))
        held_count = total - closed_count

        summary = {
            "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "total_issues_triaged": total,
            "maintainer_issues_held": maintainer_count,
            "community_issues_triaged": community_count,
            "auto_close_eligible": closed_count,
            "held_for_review": held_count,
            "all_invariants_satisfied": all(i.get("invariants_ok", False) for i in processed_issues),
        }

        # 1. Write full audit JSON
        audit_json_path = os.path.join(output_dir, "triage_audit.json")
        with open(audit_json_path, "w", encoding="utf-8") as f:
            json.dump({"summary": summary, "issues": processed_issues}, f, indent=2)

        # 2. Write summary JSON
        summary_json_path = os.path.join(output_dir, "triage_summary.json")
        with open(summary_json_path, "w", encoding="utf-8") as f:
            json.dump(summary, f, indent=2)

        # 3. Write Markdown Dashboard
        rows = []
        for i in processed_issues:
            status_badge = "🟢 Auto-Close" if i.get("can_auto_close") else "🟡 Held/Review"
            invariants_badge = "✅ PASS" if i.get("invariants_ok") else "❌ FAIL"
            rows.append(
                f"| #{i.get('issue_number')} | @{i.get('author')} | {i.get('author_type')} | {status_badge} | {invariants_badge} | {i.get('title')[:40]} |"
            )

        rows_str = "\n".join(rows) if rows else "| - | - | - | - | - | - |"
        dashboard_md = f"""# 📊 MySQLTuner Autonomous Issue Triage Dashboard

- **Last Audit Run:** {summary['generated_at']}
- **Total Issues Triaged:** `{total}`
- **Maintainer Held Issues:** `{maintainer_count}`
- **Community Resolved & Closable:** `{closed_count}`
- **Safety Invariants 100% Satisfied:** `{summary['all_invariants_satisfied']}`

---

### 📋 Triaged Issues Ledger

| Issue | Author | Role | Decision | Safety | Title |
| :--- | :--- | :--- | :--- | :--- | :--- |
{rows_str}

---
*Generated automatically by MySQLTuner Triage Audit Exporter.*
"""
        dashboard_md_path = os.path.join(output_dir, "triage_dashboard.md")
        with open(dashboard_md_path, "w", encoding="utf-8") as f:
            f.write(dashboard_md)

        return {
            "audit_json": audit_json_path,
            "summary_json": summary_json_path,
            "dashboard_md": dashboard_md_path,
        }
