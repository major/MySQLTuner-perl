---
trigger: explicit_call
description: Automate git-flow release process
category: tool
---

# Git-Flow Release Workflow

This workflow MUST be orchestrated by the **Release Manager**.

## 🧠 Constraints

- **Branch Mandatory**: The release process MUST only be executed on a dedicated branch named `vX.XX.XX` (e.g., `v2.8.41`).
- **No Main Modification**: Pushing to the `main` or `master` branch is strictly prohibited here.
- **No Automatic Bumping**: Version numbers MUST NOT be automatically incremented after release unless explicitly requested by the user.

## 🛠️ Implementation

// turbo
1. **Branch Verification**
   - Verify the current Git branch matches the `vX.XX.XX` pattern.

   ```bash
   CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
   if [[ ! "$CURRENT_BRANCH" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
     echo "ERROR: Release process must be executed on a vX.XX.XX branch."
     exit 1
   fi
   ```

2. **Run Release Preflight Workflow**
   - Execute the `/release-preflight` workflow to ensure full consistency and test passing.
   - **CRITICAL**: Do NOT proceed if `/release-preflight` fails.

   ```bash
   # Trigger preflight checks
   /release-preflight
   ```

   // turbo
3. **Commit Release Notes**
   - Commit all pending changes. The commit message MUST be strictly formatted as the release notes extracted from the `Changelog`.

   ```bash
   # Extract content between the first version header and the next one
   RELEASE_NOTES=$(awk "/^$CURRENT_VER/,/^([0-9]+\.[0-9]+\.[0-9]+)/ {if (\$0 !~ /^([0-9]+\.[0-9]+\.[0-9]+)/) print}" Changelog | sed '/^$/d')
   COMMIT_MSG="feat: release $CURRENT_VER\n\n$RELEASE_NOTES"
   git add .
   echo -e "$COMMIT_MSG" | git commit -F -
   ```

   // turbo
4. **Create Tag for Current Version**
   - Create an annotated tag incorporating the release notes.

   ```bash
   git tag -a v$CURRENT_VER -m "Release $CURRENT_VER" -m "$RELEASE_NOTES"
   ```

   // turbo
5. **Push Branch and Tag**
   - Push the current branch and the tag to the remote repository.

   ```bash
   git push origin $CURRENT_BRANCH
   git push origin v$CURRENT_VER
   ```

