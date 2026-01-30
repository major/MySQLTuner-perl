---
trigger: explicit_call
description: High-level release orchestrator for the Release Manager role
category: governance
---
# Release Manager Workflow

This workflow orchestrates the full release lifecycle. It MUST be executed by the **Release Manager**.

## 🧠 Rationale

Release integrity is guaranteed through a formal, guided protocol that minimizes manual error and ensures 100% logic validation across all transports (Standard, Container, Dumpdir).

## 🛠️ Implementation

### 1. Preparation & Validation

Before cutting a release, ensure the environment and code are stable.

// turbo

```bash
# 1. Synchronize documentation
/doc-sync

# 2. Run comprehensive pre-flight checks
/release-preflight
```

### 2. Multi-Version Testing

Execute the industrial-grade test suite against multiple DB versions.

// turbo

```bash
# 3. Validating against all core versions
make test-it
```

### 3. Artifact Generation

Generate technical documents for the new version.

// turbo

```bash
# 4. Generate release notes
/release-notes-gen
```

### 4. Git-Flow Execution

If all previous steps pass (Exit Code 0), proceed with the formal release.

// turbo

```bash
# 5. Execute git-flow
/git-flow
```

## ✅ Verification

- All workflows must return Success.
- Final version consistency check in `v2.9.0` release notes.
- Tag and Push verified in remote repository.
