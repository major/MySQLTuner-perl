# Specification: Persistent Lab Environment

## 🧠 Rationale

Current testing (via `build/test_envs.sh`) restarts containers for every run. This is time-consuming for iterative debugging and bug analysis. A persistent environment allows developers to keep containers running, manually inspect the database, and run `mysqltuner.pl` multiple times with zero overhead.

## 🛠️ Implementation

### 1. Environment Lifecycle Control

- Add `--keep-alive` (or `-k`) to `build/test_envs.sh`.
- When set, `run_test_lab` will SKIP the `make stop` command at the end.
- Add `--no-injection` (or `-n`) to `build/test_envs.sh`.
- When set, `run_test_lab` will SKIP the data injection phase (useful if data is already persistent in volumes or just to speed up repeated runs).

### 2. Direct Execution Helper

- Encourage direct execution of `mysqltuner.pl`:

  ```bash
  perl mysqltuner.pl --host 127.0.0.1 --user root --pass mysqltuner_test
  ```

- Add a helper command in `Makefile` to run against the last started lab.

### 3. Workflow for Rapid Debugging

- `/lab-up`: Starts the laboratory for a specific config and keeps it running.
- `/lab-down`: Stops and cleans up the laboratory.

## ✅ Verification

- Start a lab with `--keep-alive`.
- Verify containers are still running after script completion.
- Run `mysqltuner.pl` manually against the running container.
- Stop the lab manually.
