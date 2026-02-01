---
description: Synchronize .agent/README.md with current Rules, Skills, and Workflows
---
# Doc-Sync Workflow

## 🧠 Rationale

Keeps the project's technical summary up-to-date with all available governance assets.

## 🛠️ Implementation

1. Scan `.agent/rules/`, `.agent/skills/`, and `.agent/workflows/`.
2. Update `.agent/README.md` with a structured list of these items.
3. Ensure absolute paths are converted to relative paths for portability.

## ✅ Verification

- Verify `.agent/README.md` is updated and matches the filesystem.
