---
description: Pre-flight checks before triggering a git-flow release
---

# Release Preflight Workflow

Ensure consistency across versioning artifacts before cutting a release.

## 1. Extract Versions

```bash
# 1. mysqltuner.pl internal version
SCRIPT_VER=$(grep "mysqltuner.pl v" mysqltuner.pl | head -n 1 | awk '{print $2}' | sed 's/v//')

# 2. CURRENT_VERSION.txt
TXT_VER=$(cat CURRENT_VERSION.txt)

# 3. Changelog latest version
LOG_VER=$(head -n 1 Changelog | awk '{print $1}')
```

## 2. Validate Consistency

All three versions must match.

```bash
if [ "$SCRIPT_VER" == "$TXT_VER" ] && [ "$TXT_VER" == "$LOG_VER" ]; then
    echo "SUCCESS: Versions match ($SCRIPT_VER)."
else
    echo "FAIL: Version Mismatch!"
    echo "Script:    $SCRIPT_VER"
    echo "Txt:       $TXT_VER"
    echo "Changelog: $LOG_VER"
    exit 1
fi
```

## 3. Smoke Test

Run the primary test suite to ensure the build isn't broken.

```bash
# Assuming make test exists and runs the suite
make test
```

## 4. Proceed to Release

If all checks pass, proceed with `/git-flow`.
