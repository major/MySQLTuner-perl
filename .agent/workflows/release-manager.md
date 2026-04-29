---
trigger: explicit_call
description: High-level release orchestrator for the Release Manager role
category: governance
---
# Release Manager Workflow

This workflow orchestrates the full release lifecycle. It MUST be executed by the **Release Manager**.

## 🧠 Rationale

Release integrity is guaranteed through a unified, formal protocol that minimizes manual error, consolidates numerous fragmented steps, and ensures 100% logic validation across all environments.

## 🛠️ Implementation

### 1. Preparation & Validation

Before cutting a release, ensure the environment and code are stable.
1. Synchronize `.agent/README.md` with current Rules, Skills, and Workflows.
2. Verify version consistency across `CURRENT_VERSION.txt`, `Changelog`, and `mysqltuner.pl`.
3. Audit for any uncommitted changes or missing files.

### 2. Multi-Version Testing

Execute the industrial-grade test suite against multiple DB versions.

// turbo

```bash
# Validating against all core versions
make test-all
```

### 3. Artifact & Notes Generation

Generate technical documents for the new version.
1. Draft comprehensive release notes in `releases/v[VERSION].md` summarizing changes from `@Changelog`.
2. Format using Conventional Commits classification.

### 4. Git-Flow Execution

If all previous steps pass (Exit Code 0), proceed with the formal release.
1. Ensure you are on a release branch `vX.XX.XX`.
2. Commit all changes including documentation and release notes via `npm run commit` or `git cz`.
3. Merge branch back to `master`.
4. Tag the release on `master` with the new version.
5. Force push tags and `master` to origin.

## ✅ Verification

- Tests pass successfully across all supported versions.
- Release notes exist in `releases/v[VERSION].md`.
- Git history correctly reflects semantic versions and tags.

