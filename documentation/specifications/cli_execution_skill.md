---
test_file: tests/cli_options.t
title: CLI Execution Mastery Skill Specification
status: proposed
author: Antigravity
date: 2026-01-25
---

# Specification: CLI Execution Mastery Skill

## Goal

Provide instructions and reference options for executing MySQLTuner via command-line interfaces across standalone, containerized, and remote SSH environments.

## 🧠 Rationale

The MySQLTuner project has numerous CLI options for connection and authentication. Enabling the agent to master these options ensures it can run the script in any environment (local, remote, container, cloud) using existing configuration files like `.my.cnf` or environment variables, without needing sensitive information to be hardcoded.

## 🛠️ Requirements

1. **Skill Location**: `.agent/skills/cli-execution-mastery/SKILL.md`
2. **Scope**:
    - Connection parameters (`--host`, `--port`, `--socket`).
    - Authentication methods (`--user`, `--pass`, `--userenv`, `--passenv`).
    - Configuration file usage (`--defaults-file`, `--defaults-extra-file`).
    - Container and Cloud modes (`--container`, `--cloud`).
    - Password management (`--passwordfile`, `--skippassword`).
3. **Instructional Content**:
    - How to discover existing `.my.cnf` files.
    - How to use environment variables for safe credential passing.
    - How to handle different connection protocols (socket vs TCP).

## ✅ Verification

- The skill must be registered in `.agent/README.md`.
- The skill must follow the AFF (Agent-Friendly Format) with frontmatter.
- The instructions must be technically accurate according to `mysqltuner.pl` source code.

## Verification

- Validated via `tests/cli_options.t` and `tests/cli_validation.t`.
- Verified parameter parsing for connection options (`--host`, `--port`, `--socket`, `--user`, `--pass`).
