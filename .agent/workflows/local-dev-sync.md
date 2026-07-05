---
trigger: explicit_call
description: Synchronize developer changes, run unit tests, and update changelog and release notes.
category: tool
---

# Local Developer Sync Workflow

This workflow provides local synchronization automation for the developer, ensuring version consistency, automatic changelog sorting, release notes updating, unit testing, and git delivery.

## 🧠 Rationale

Ensuring a clean and synchronized branch history, accurate release documentation, and fully passing unit tests before any push to the remote repository.

## 🛠️ Implementation

Run the local dev-sync orchestrator script:

// turbo

```bash
perl build/dev_sync.pl
```

## ✅ Verification

- The script returns exit code 0.
- All version files are confirmed to be consistent.
- `Changelog` is updated and sorted according to the Conventional Commit categories.
- `releases/v[VERSION].md` matches the latest entries.
- All local unit tests passed successfully.
- Modified release files are committed and pushed to `origin`.
