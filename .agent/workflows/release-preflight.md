---
trigger: explicit_call
description: Pre-flight checks before triggering a git-flow release
category: tool
---

# Release Preflight Workflow

Ensure consistency across versioning artifacts before cutting a release.

## 1. Extract Versions

```bash
# 1. CURRENT_VERSION.txt
TXT_VER=$(cat CURRENT_VERSION.txt | tr -d '[:space:]')

# 2. mysqltuner.pl internal variable
SCRIPT_VAR_VER=$(grep "my \$tunerversion =" mysqltuner.pl | cut -d'"' -f2)

# 3. mysqltuner.pl header version
SCRIPT_HEAD_VER=$(grep "# mysqltuner.pl - Version" mysqltuner.pl | head -n 1 | awk '{print $NF}')

# 4. mysqltuner.pl POD Name version
SCRIPT_POD_NAME_VER=$(grep "MySQLTuner [0-9.]* - MySQL High Performance" mysqltuner.pl | awk '{print $2}')

# 5. mysqltuner.pl POD Version section
SCRIPT_POD_VER=$(grep "^Version [0-9.]*" mysqltuner.pl | awk '{print $2}')

# 6. Changelog latest version
LOG_VER=$(head -n 1 Changelog | awk '{print $1}')
```

## 2. Validate Consistency

All version occurrences must match `CURRENT_VERSION.txt`.

```bash
FAILED=0
for VER in "$SCRIPT_VAR_VER" "$SCRIPT_HEAD_VER" "$SCRIPT_POD_NAME_VER" "$SCRIPT_POD_VER" "$LOG_VER"; do
    if [ "$VER" != "$TXT_VER" ]; then
        FAILED=1
    fi
done

if [ $FAILED -eq 0 ]; then
    echo "SUCCESS: All versions match ($TXT_VER)."
else
    echo "FAIL: Version Mismatch detected!"
    echo "Txt:              $TXT_VER"
    echo "Script Variable:  $SCRIPT_VAR_VER"
    echo "Script Header:    $SCRIPT_HEAD_VER"
    echo "Script POD Name:  $SCRIPT_POD_NAME_VER"
    echo "Script POD Ver:   $SCRIPT_POD_VER"
    echo "Changelog:        $LOG_VER"
    exit 1
fi
```

## 3. Automated Consistency Test

Run the dedicated test to ensure all version strings are synchronized.

```bash
prove tests/version_consistency.t
```

## 4. Commit Log Validation

Ensure all commits since the last release follow Conventional Commits.

```bash
LAST_TAG=$(git describe --tags --abbrev=0)
echo "Validating commits since $LAST_TAG..."
npx commitlint --from=$LAST_TAG --to=HEAD
```

## 5. Markdown Integrity

Audit project documentation for cleanliness and standard compliance.

```bash
# Executing markdown linting across .agent and documentation
python3 build/md_lint.py --all
```

## 6. Smoke Test

Run the primary test suite to ensure the build isn't broken.

```bash
# Assuming make test exists and runs the suite
make test
```

## 5. Proceed to Release

If all checks pass, proceed with `/git-flow`.
