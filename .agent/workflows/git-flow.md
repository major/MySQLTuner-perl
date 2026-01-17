---
description: Automate git-flow release process
---

1. **Ensure clean working tree**

   ```bash
   git status --porcelain
   ```

   // turbo
2. **Update version**
   - Increment patch version in `CURRENT_VERSION.txt` (e.g., `1.0.9` → `1.0.10`).
   - Update `$tunerversion` variable in `mysqltuner.pl` header.

   ```bash
   NEW_VER=$(awk -F. '{print $1"."$2"."($3+1)}' CURRENT_VERSION.txt)
   echo $NEW_VER > CURRENT_VERSION.txt
   sed -i "s/\$tunerversion = .*/\$tunerversion = \"$NEW_VER\";/" mysqltuner.pl
   ```

   // turbo
3. **Update Changelog**
   - Prepend entry with new version and date.

   ```bash
   DATE=$(date +%Y-%m-%d)
   echo "$NEW_VER $DATE" > tmp_changelog && cat Changelog >> tmp_changelog && mv tmp_changelog Changelog
   ```

   // turbo
4. **Commit changes**

   ```bash
   git add CURRENT_VERSION.txt mysqltuner.pl Changelog
   git commit -m "feat: release $NEW_VER"
   ```

   // turbo
5. **Create tag**

   ```bash
   git tag -a v$NEW_VER -m "Release $NEW_VER"
   ```

   // turbo
6. **Push branch and tags**

   ```bash
   git push origin main
   git push origin v$NEW_VER
   ```

   // turbo
