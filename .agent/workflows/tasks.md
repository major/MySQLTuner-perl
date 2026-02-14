---
trigger: explicit_call
description: Break down an approved plan into actionable tasks (task.md)
category: governance
---

# Task Management Workflow (SDD)

## 🧠 Rationale

Complexity management requires breaking large technical changes into atomic, trackable units. This improves predictability and provides transparency into implementation progress.

## 🛠️ Implementation

### 1. Artifact Definition

The principal artifact is `task.md`. Each task must follow the format:

- `[ ] [ID] [Priority] [Story Reference] Description`

Example:

- `[ ] [0] [P1] [STORY:PK_DETECTION] Implement missing PK check in mysql_table_structures`

### 2. Execution Steps

1. **Prerequisite**: Ensure an `implementation_plan.md` has been approved.
2. **Initialize**: Call `/tasks` to populate `task.md`.
3. **Synchronization**: Ensure tasks map directly to the proposed architecture in the plan.
4. **Tracking**: Update task status from `[ ]` to `[/]` (in-progress) and `[x]` (completed).

## ✅ Verification

- Ensure `task.md` is updated and reflects the current state of work.
- Validate that all mandatory ID and Priority metadata are present.
