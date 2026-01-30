# Specification - Release Manager

## 🧠 Rationale

To ensure high-density development and production stability, a formal **Release Manager** entity is required to orchestrate the transition from implementation to distribution. This role bridges the gap between the AI Product Manager's execution and the Owner's approval.

## User Scenarios

- **Scenario 1**: A new patch version is ready. The Release Manager triggers preflight checks, validates consistency, and generates release notes.
- **Scenario 2**: A breaking change is detected during preflight. The Release Manager halts the release and initiates a rollback or fix.
- **Scenario 3**: The Owner requires a technical summary of the release. The Release Manager provides the generated release notes and validation reports.

## Proposed Scope

1. **Governance**: Formalize the "Release Manager" role in `ROADMAP.md` and `00_constitution.md`.
2. **Responsibilities**:
    - Final validation of version consistency.
    - Execution of the tripartite testing scenario (Standard, Container, Dumpdir).
    - Maintenance of the `Changelog` and release notes artifacts.
    - Orchestration of the `/git-flow` lifecycle.
3. **Automation**: Refine the `/git-flow` and `/release-preflight` workflows to be "Release Manager" aware.

## Verification

- Compliance with the Project Constitution.
- Successful execution of a full release cycle (v2.9.0).
