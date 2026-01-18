---
description: Automate git-flow release process
---

1. **Ensure clean working tree and Pre-flight Consistency Check**
   - Verify that `Changelog`, `CURRENT_VERSION.txt`, and `mysqltuner.pl` are synchronized.

   ```bash
   git status --porcelain
   CURRENT_VER=$(cat CURRENT_VERSION.txt | tr -d '[:space:]')
   SCRIPT_VER=$(grep "my \$tunerversion =" mysqltuner.pl | cut -d'"' -f2)
   CHANGELOG_VER=$(head -n 1 Changelog | awk '{print $1}')

   echo "Checking version consistency: $CURRENT_VER"
   
   if [ "$CURRENT_VER" != "$SCRIPT_VER" ]; then
       echo "ERROR: CURRENT_VERSION.txt ($CURRENT_VER) does not match mysqltuner.pl ($SCRIPT_VER)"
       exit 1
   fi

   if [ "$CURRENT_VER" != "$CHANGELOG_VER" ]; then
       echo "ERROR: CURRENT_VERSION.txt ($CURRENT_VER) does not match Changelog ($CHANGELOG_VER)"
       exit 1
   fi
   
   echo "Consistency check passed."
   ```

   // turbo
2. **Commit Current Changes**
   - Commit all pending changes including `Changelog` updates for the current version.

   ```bash
   git add .
   git commit -m "feat: release $CURRENT_VER"
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
   sed -i "s/my \$tunerversion = .*/my \$tunerversion = \"$NEW_VER\";/" mysqltuner.pl
   
   DATE=$(date +%Y-%m-%d)
   echo -e "$NEW_VER $DATE\n\n- \n" > tmp_changelog && cat Changelog >> tmp_changelog && mv tmp_changelog Changelog
   ```

   // turbo
6. **Commit Version Bump**
   - Commit the incremented version for the next development cycle.

   ```bash
   git add CURRENT_VERSION.txt mysqltuner.pl Changelog
   git commit -m "chore: bump version to $NEW_VER"
   git push origin main
   ```

   // turbo
