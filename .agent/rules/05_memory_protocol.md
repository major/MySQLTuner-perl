---
trigger: always_on
description: Protocols for maintaining contextual consistency and history.
category: governance
---

# **5\. 📜 STATE MEMORY & HISTORY**

## **Contextual Consistency Protocols**

1. **History Update:** Add new entries to the top of `Changelog` if the action is correct and tested.

- Ensure consistency between `CURRENT_VERSION.txt`
- Check MySQLTuner version inside `mysqltuner.pl` (header, internal variable, and POD documentation)
- Match `Changelog` last version

1. **Git Sync:** Consult `git log -n 15` to synchronize context.
2. **Rotation:** FIFO Rotation (Max 600 lines). Remove oldest entries beyond 600 lines.

3. All changes must be added to the latest version in `Changelog`.
4. No version increment unless explicit git commit/tag/push via `/git-flow` or specific user order has been made.
5. After Git tag and push, version management is handled by the Release Manager or via `/git-flow`. The agent MUST NOT increment version numbers autonomously.

### **History Entry example**

1.0.9 2026-01-16

- chore: migrate HISTORY.md into Changelog and remove HISTORY.md.
