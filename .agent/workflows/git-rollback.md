---
description: Rollback a failed release (delete tags and revert commits)
---

1. **Delete Local and Remote Tag**
   - Identify the tag to remove from `CURRENT_VERSION.txt`.

   ```bash
   VERSION_TO_ROLLBACK=$(cat CURRENT_VERSION.txt)
   echo "Rolling back version v$VERSION_TO_ROLLBACK"
   
   git tag -d v$VERSION_TO_ROLLBACK
   git push --delete origin v$VERSION_TO_ROLLBACK
   ```

   // turbo
2. **Revert Release Commits**
   - Reset the branch to the state before the release commit.
   - **WARNING**: This uses `git reset --hard`. Ensure you don't have uncommitted work you want to keep.

   ```bash
   # Identify the commit before the release commit (assuming the last commit was the version bump)
   # We might want to revert the last 2 commits: the bump and the release tag commit.
   
   # Reset to 2 commits ago
   git reset --hard HEAD~2
   
   # Force push to clean remote main branch
   # git push origin main --force
   ```

   // turbo
3. **Notify User**
   - The rollback is completed locally. Remote sync may require a force push.

   > [!CAUTION]
   > The local branch has been reset. If you had already pushed the version bump, you may need to run `git push origin main --force` to synchronize the remote branch.
