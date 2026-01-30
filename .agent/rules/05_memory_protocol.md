---
trigger: always_on
description: Protocols for maintaining contextual consistency and history.
category: governance
---

# **5\. 📜 STATE MEMORY & HISTORY**

## **Contextual Consistency Protocols**

1. **History Update:** Add new entries to the top of Changelog if the action is correct and tested.  
Changelog is a file at root of this projet
insure consistency between CURRENT_VERSION.txt
MySQLtuner version inside mysqltuner.pl (begin of script this script and begin of pod doc =pod)
Changelog last version

2. **Git Sync:** Consult git log \-n 15 to synchronize context.  
3. **Rotation:** FIFO Rotation (Max 600 lines). Remove oldest entries beyond 600 lines.

4. All changes must be added to last version in `Changelog`.
5. No increment version if explicit git commit/tag/push via `/git-flow` or specific order from previous version hasn't been made.
6. After Git tag and push, version should be managed by the Release Manager or via the `/git-flow` lifecycle. The agent MUST NOT increment version numbers autonomously.

### **History Entry example**

1.0.9 2026-01-16

- chore: migrate HISTORY.md into Changelog and remove HISTORY.md.
