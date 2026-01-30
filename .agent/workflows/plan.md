---
trigger: explicit_call
description: Create or update an implementation plan (implementation_plan.md)
category: governance
---

# Planning Workflow (SDD)

## 🧠 Rationale

A well-defined plan bridges the gap between requirements and code. It allows for early identification of technical risks, architectural debt, and performance bottlenecks.

## 🛠️ Implementation

### 1. Artifact Definition

The principal artifact is `implementation_plan.md`. It must contain:

- **Summary**: High-level overview of the proposed technical changes.
- **Technical Context**: Language, core dependencies (Base Perl only!), and storage/memory impacts.
- **Proposed Architecture**: Detailed list of files to be modified/created.
- **Risks & Limitations**: Performance impact, regression risks, or compatibility constraints.
- **Open Questions**: Points requiring user clarification.

### 2. Execution Steps

1. **Prerequisite**: Ensure a `specification.md` has been approved.
2. **Initialize**: Call `/plan` to generate the technical strategy.
3. **Audit**: Check the plan against the **Project Constitution** (Single File, Core-only).
4. **Review**: Submit for user approval via `notify_user`.

## ✅ Verification

- Validate the plan follows the "Single File" architecture constraint.
- Ensure all technical risks are addressed or documented.
