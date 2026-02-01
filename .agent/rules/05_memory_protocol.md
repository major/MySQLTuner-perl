---
trigger: always_on
description: Contextual consistency and history protocols.
category: governance
---
# **5. 📜 STATE MEMORY & HISTORY**

## **Contextual Consistency Protocols**

1. **History Update**: Add new entries to the top of `Changelog` if the action is correct and tested.
2. **Rotation**: FIFO Rotation (Max 600 lines). Remove oldest entries beyond 600 lines.
3. **Changelog**: All changes MUST be traced and documented inside `Changelog`.

### **History Entry example**

1.0.1 2026-02-01

- feat: establish .agent governance and aesthetic verification.
