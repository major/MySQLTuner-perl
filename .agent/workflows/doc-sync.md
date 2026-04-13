---
trigger: /doc-sync
description: Synchronize .agent/README.md with current Rules, Skills, and Workflows
category: Documentation
---

# Documentation Synchronization Workflow

1. Execute the documentation synchronization script to update `.agent/README.md`:
// turbo

```bash
python3 build/doc_sync.py
```

1. **Full Documentation Review Checklist**:
    - [ ] **READMEs**: Verify `README.md` and translations are up-to-date with new features.
    - [ ] **Usage**: Ensure `mysqltuner.pl --help` output matches `CLI_METADATA` in script.
    - [ ] **ROADMAP.md**: Move completed items from Phase 2/3 to COMPLETED.
    - [ ] **POTENTIAL_ISSUES**: Audit found anomalies and update it if needed.
    - [ ] **Script Comments**: Verify internal documentation matches logic changes.

2. **Version Consistency Audit**:
    - [ ] `CURRENT_VERSION.txt` matches `$tunerversion` in `mysqltuner.pl`.
    - [ ] Script header and POD documentation reflect the current version.
    - [ ] `Changelog` contains a section for the current version with correct date.
    - [ ] `releases/v[VERSION].md` exists and is synchronized with `Changelog`.

3. Review the updated summary in [.agent/README.md](file://.agent/README.md).
