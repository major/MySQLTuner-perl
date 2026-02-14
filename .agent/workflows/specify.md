---
trigger: explicit_call
description: Create or update a feature specification (specification.md)
category: governance
---

# Specification Workflow (SDD)

## 🧠 Rationale

Before writing any code or even planning the technical implementation, we must define **what** we are building and **why**. Spec-Driven Development ensures that features are grounded in real user needs and have clear, testable success criteria.

## 🛠️ Implementation

### 1. Artifact Definition

The principal artifact is a specific file in `documentation/specifications/`. It must contain:

- **Metadata**: Feature Name, Status (Draft/Approved), Created Date.
- **User Scenarios**: Narratives describing how users will interact with the feature.
- **User Stories**: A table mapping needs to requirements.

| Title | Priority | Description | Rationale | Test Case |
| :--- | :--- | :--- | :--- | :--- |
| [Story Name] | [P1-P3] | I want to... | So that... | GIVEN... WHEN... THEN... |

### 2. Execution Steps

1. **Initialize**: Call `/specify` to start a new feature or refine an existing one.
2. **Gather Scenarios**: Define at least 2 relevant user scenarios.
3. **Draft Stories**: Break scenarios into atomic user stories with testable criteria.
4. **Review**: Submit for user approval via `notify_user`.

## ✅ Verification

- Check for presence of all mandatory sections in the specification file.
- Ensure every story has a corresponding test case.
