---
trigger: always_on
description: Overview of project governance, skills, and workflows
category: governance
---
# .agent - Project Governance & Artificial Intelligence Intelligence

This directory contains the project's technical constitution, specialized skills, and operational workflows used by AI agents.

## Governance & Execution Constraints

| File | Description |
| :--- | :--- |
| [`00_constitution.md`](./rules/00_constitution.md) | Core mission and unique source of truth for the project. |
| [`01_objective.md`](./rules/01_objective.md) | Current project roadmap and success criteria. |
| [`02_architecture.md`](./rules/02_architecture.md) | Immutable project architecture and technology stack. |
| [`03_execution_rules.md`](./rules/03_execution_rules.md) | Core project constitution and hard execution constraints. |
| [`04_best_practices.md`](./rules/04_best_practices.md) | Technical best practices and recommended internal patterns. |
| [`05_memory_protocol.md`](./rules/05_memory_protocol.md) | Protocols for maintaining contextual consistency and history. |
| [`remembers.md`](./rules/remembers.md) | "Persistent memory for emerging patterns and session-specific dynamic rules" |


## Specialized Capabilities & Knowledge

| File | Description |
| :--- | :--- |
| [`cli-execution-mastery/`](./skills/cli-execution-mastery/SKILL.md) | Mastery of MySQLTuner CLI options for connection and authentication. |
| [`db-version-rift/`](./skills/db-version-rift/SKILL.md) | Mapping of critical differences between MySQL and MariaDB versions for cross-compatible diagnostics. |
| [`legacy-perl-patterns/`](./skills/legacy-perl-patterns/SKILL.md) | Guidelines and patterns for maintaining backward compatibility with older Perl versions (5.8+). |
| [`testing-orchestration/`](./skills/testing-orchestration/SKILL.md) | Knowledge on how to run, orchestrate, and validate tests in the MySQLTuner project. |


## Automation & Operational Workflows

| File | Description |
| :--- | :--- |
| [`compliance-sentinel.md`](./workflows/compliance-sentinel.md) | Automated audit to enforce project constitution rules |
| [`doc-sync.md`](./workflows/doc-sync.md) | Synchronize .agent/README.md with current Rules, Skills, and Workflows |
| [`docker-clean.md`](./workflows/docker-clean.md) | Reclaim disk space by removing unused containers and images |
| [`examples-cleanup.md`](./workflows/examples-cleanup.md) | Maintain only the 10 most recent results in the examples directory |
| [`git-flow.md`](./workflows/git-flow.md) | Automate git-flow release process |
| [`git-rollback.md`](./workflows/git-rollback.md) | Rollback a failed release (delete tags and revert commits) |
| [`hey-agent.md`](./workflows/hey-agent.md) | Unified management for Rules, Skills, and Workflows. |
| [`lab-down.md`](./workflows/lab-down.md) | Stops and cleans up the database laboratory. |
| [`lab-up.md`](./workflows/lab-up.md) | Starts a persistent database laboratory and injects data. |
| [`markdown-lint.md`](./workflows/markdown-lint.md) | Check markdown content for cleanliness and project standard compliance (AFF, keywords, links) |
| [`plan.md`](./workflows/plan.md) | Create or update an implementation plan (implementation_plan.md) |
| [`release-manager.md`](./workflows/release-manager.md) | High-level release orchestrator for the Release Manager role |
| [`release-notes-gen.md`](./workflows/release-notes-gen.md) | Generate detailed technical release notes for the current version |
| [`release-preflight.md`](./workflows/release-preflight.md) | Pre-flight checks before triggering a git-flow release |
| [`run-tests.md`](./workflows/run-tests.md) | Comprehensive test suite execution (Unit, Regression, and Multi-DB) |
| [`snapshot-to-test.md`](./workflows/snapshot-to-test.md) | Transform a running production issue into a reproducible test case |
| [`specify.md`](./workflows/specify.md) | Create or update a feature specification (specification.md) |
| [`tasks.md`](./workflows/tasks.md) | Break down an approved plan into actionable tasks (task.md) |


---
*Generated automatically by `/doc-sync` on Sat Feb 14 11:35:52 CET 2026*