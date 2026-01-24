---
description: Automate git-flow release process
---

1. **Run Release Preflight Workflow**
   - Execute the `/release-preflight` workflow to ensure full consistency and test passing.
   - **CRITICAL**: Do NOT proceed if `/release-preflight` fails.

   ```bash
   # Trigger preflight checks
   /release-preflight
   ```

   // turbo
2. **Commit Current Changes**
   - Commit all pending changes including `Changelog` updates for the current version.

   ```bash
   git add .
   npm run commit  # Select 'feat' and enter "release $CURRENT_VER"
   ```

   // turbo
3. **Create Tag for Current Version with Changelog content**
   - Extract the latest release notes and create an annotated tag.

   ```bash
   # Extract content between the first version header and the next one
   TAG_MSG=$(awk "/^$CURRENT_VER/,/^([0-9]+\.[0-9]+\.[0-9]+)/ {if (\$0 !~ /^([0-9]+\.[0-9]+\.[0-9]+)/) print}" Changelog | sed '/^$/d')
   git tag -a v$CURRENT_VER -m "Release $CURRENT_VER" -m "$TAG_MSG"
   ```

   // turbo
4. **Push Branch and Tag**
   - Push to the remote repository.

   ```bash
   git push origin main
   git push origin v$CURRENT_VER
   ```

   // turbo
5. **Post-Push: Increment Version for Next Cycle**
   - Calculate the next patch version and update files.

   ```bash
   NEW_VER=$(echo $CURRENT_VER | awk -F. '{print $1"."$2"."($3+1)}')
   echo $NEW_VER > CURRENT_VERSION.txt
   # Update all version occurrences in mysqltuner.pl
   perl -pi -e "s/\Q$CURRENT_VER\E/$NEW_VER/g" mysqltuner.pl
   
   DATE=$(date +%Y-%m-%d)
   echo -e "$NEW_VER $DATE\n\n- \n" > tmp_changelog && cat Changelog >> tmp_changelog && mv tmp_changelog Changelog
   ```

   // turbo
6. **Commit Version Bump**
   - Commit the incremented version for the next development cycle.

   ```bash
   git add CURRENT_VERSION.txt mysqltuner.pl Changelog
   npx commitlint --from=HEAD~1 # Or simply use npm run commit if not automated
   git commit -m "chore: bump version to $NEW_VER"
   git push origin main
   ```

   // turbo
