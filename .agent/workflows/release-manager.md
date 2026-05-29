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

### 4. Branch Creation & Lifecycle Management

All development and release operations follow a strict branch isolation protocol:
1. **Feature/Bugfix Branches**: Create a dedicated branch from `master` named `feat/[name]`, `fix/[name]`, or `chore/[name]`.
   ```bash
   git checkout -b feat/my-new-feature
   ```
2. **Release Branches**: When preparing a release, create a release branch named `vX.XX.XX` (e.g., `v2.8.44`) from `master`.
   ```bash
   git checkout -b v2.8.44
   ```
   *Note: Upon checkout, the post-checkout hook automatically runs `tests/version_consistency.t` to verify version files are in sync.*
3. **Development Cycle**: Develop features, bug fixes, or chores, committing them using Conventional Commits via `npm run commit` or `git cz`.

### 5. Git-Flow & Release Execution

Once the release branch is ready and all compliance checks pass:
1. Run `make release VERSION=X.XX.XX` to automatically bump the version in all source files, regenerate `USAGE.md`, and generate release notes.
2. Verify compliance locally by running `perl build/check_compliance.pl`.
3. Commit all generated release artifacts (e.g. `releases/vX.XX.XX.md`, updated `mysqltuner.pl`, `CURRENT_VERSION.txt`, `Changelog`) using `npm run commit`.
4. Merge the release branch back into `master`.
   ```bash
   git checkout master
   git merge --no-ff vX.XX.XX
   ```
5. Tag the release on `master`:
   ```bash
   git tag -a vX.XX.XX -m "Release vX.XX.XX"
   ```
6. Push changes and tags to origin:
   ```bash
   git push origin master --tags
   ```
7. Clean up the local release branch:
   ```bash
   git branch -d vX.XX.XX
   ```

## ✅ Verification

- Tests pass successfully across all supported versions.
- Release notes exist in `releases/v[VERSION].md`.
- Git history correctly reflects semantic versions and tags.


