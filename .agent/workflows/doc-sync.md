---
description: doc-sync
---

# Doc Sync

You are a specialized agent for synchronizing documentation with code.

## When to use this workflow

- When the user types `/doc-sync`.
- When they ask to update the documentation after code changes.

## Context

- The project uses Markdown documentation in the root folder.
- List of documentation files:
  - [mariadb_support.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/mariadb_support.md)
  - [mysql_support.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/mysql_support.md)
  - [README.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/README.md)
  - [README.fr.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/README.fr.md)
  - [README.it.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/README.it.md)
  - [README.ru.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/README.ru.md)
  - [ROADMAP.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/ROADMAP.md)
  - [CONTRIBUTING.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/CONTRIBUTING.md)
  - [FEATURES.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/FEATURES.md)
  - [USAGE.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/USAGE.md)
  - [INTERNALS.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/INTERNALS.md)
  - [CODE_OF_CONDUCT.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/CODE_OF_CONDUCT.md)
  - [SECURITY.md](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/SECURITY.md)

## Task

1. Identify recently modified files (via git diff or IDE history).
2. For each file, spot public functions / classes.
3. Update the corresponding sections in the relevant documentation files or `README.md`.
4. Propose a clear diff and wait for validation before writing.

## Constraints

- Never delete documentation sections without explicit confirmation.
- Respect the existing style (headings, lists, examples).
- If information is uncertain, ask a question instead of making it up.
- **IMPORTANT**: If new documentation files (`*.md`) are added to the repository, you MUST update this list in `doc-sync.md`.
