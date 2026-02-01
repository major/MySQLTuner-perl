---
trigger: explicit_call
description: Pre-flight checks before triggering a git-flow release
category: tool
---
# Release Preflight Workflow (MT-site)

## 1. Extract Versions

```bash
TXT_VER=$(cat CURRENT_VERSION.txt | tr -d '[:space:]')
LOG_VER=$(head -n 1 Changelog | awk '{print $1}')
```

## 2. Validate Consistency

```bash
if [ "$LOG_VER" != "$TXT_VER" ]; then
    echo "FAIL: Version Mismatch detected!"
    echo "Txt: $TXT_VER"
    echo "Changelog: $LOG_VER"
    exit 1
else
    echo "SUCCESS: Versions match ($TXT_VER)."
fi
```

## 3. Aesthetic Sanity Check

- Run `/local-preview` and check for 404s.
- Run `/visual-audit` and confirm "PASS".

## 4. Documentation Sync

- Run `/doc-sync` to ensure .agent/README.md is up-to-date.

## 5. Proceed to Release

If all checks pass, proceed with `/git-flow`.
