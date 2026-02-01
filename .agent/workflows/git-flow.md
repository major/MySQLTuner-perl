---
description: Automate git-flow release process for MT-site
---
# Git-Flow Release Workflow (MT-site)

1. **Run Release Preflight Workflow**
   - Execute the `/release-preflight` workflow.

   ```bash
   /release-preflight
   ```

2. **Commit Current Changes**
   - Commit pending changes including governance and fixes.

   ```bash
   git add .
   # Use conventional commit
   git commit -m "feat: release $CURRENT_VER"
   ```

3. **Create Tag for Current Version**

   ```bash
   TAG_MSG=$(awk "/^$CURRENT_VER/,/^([0-9]+\.[0-9]+\.[0-9]+)/ {if (\$0 !~ /^([0-9]+\.[0-9]+\.[0-9]+)/) print}" Changelog | sed '/^$/d')
   git tag -a v$CURRENT_VER -m "Release $CURRENT_VER" -m "$TAG_MSG"
   ```

4. **Push Branch and Tag**

   ```bash
   git push origin main
   git push origin v$CURRENT_VER
   ```

5. **Post-Push: Increment Version**

   ```bash
   NEW_VER=$(echo $CURRENT_VER | awk -F. '{print $1"."$2"."($3+1)}')
   echo $NEW_VER > CURRENT_VERSION.txt
   DATE=$(date +%Y-%m-%d)
   echo -e "$NEW_VER $DATE\n\n- \n" > tmp_changelog && cat Changelog >> tmp_changelog && mv tmp_changelog Changelog
   ```

6. **Commit Version Bump**

   ```bash
   git add CURRENT_VERSION.txt Changelog
   git commit -m "chore: bump version to $NEW_VER"
   git push origin main
   ```
