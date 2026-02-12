# Specification: Fix --dumpdir TRUE/FALSE logic

- **Feature Name**: --dumpdir logic fix
- **Status**: Draft
- **Created Date**: 2026-02-13

## 🧠 Rationale

Currently, when `mysqltuner.pl` is run without the `--dumpdir` option, it defaults to `'0'`. The internal logic in `dump_csv_files` only skips execution if `dumpdir` is an empty string (`''`). Since `'0'` is not `''`, the script proceeds to create a directory named `0` and dumps CSV files into it.

This behavior is undesirable. If `--dumpdir` is not explicitly set to a valid path, no dumping should occur.

## 🛠️ User Scenarios

### Scenario 1: Standard Execution (No Dump)

User runs `mysqltuner.pl` without any dump options.

- **Command**: `perl mysqltuner.pl`
- **Expected Result**: No directory `0` is created. No CSV files are dumped.

### Scenario 2: Explicit Dump

User runs `mysqltuner.pl` with a specific directory.

- **Command**: `perl mysqltuner.pl --dumpdir ./results`
- **Expected Result**: Directory `./results` is created (if missing). CSV files are dumped there.

### Scenario 3: Empty or '0' value (Regression found)

User runs `mysqltuner.pl --dumpdir 0` or similar.

- **Command**: `perl mysqltuner.pl --dumpdir 0`
- **Expected Result**: The script should treat this as "no dump" OR display an error if the user intended to dump but provided an invalid directory name. According to the maintainer, it should exit gently or just not dump if it's effectively disabled.

## 📋 User Stories

| Title | Priority | Description | Rationale | Test Case |
| :--- | :--- | :--- | :--- | :--- |
| Prevent Default Dump | P1 | As a user, I don't want any dump directories created unless I specify one | Avoid polluting the filesystem | Run without `--dumpdir`, verify `0/` does not exist. |
| Consistent Default Handling | P1 | As a developer, I want `dumpdir` to follow the same '0' = disabled convention as other CLI options | Code maintainability | Verify `$opt{dumpdir} eq '0'` skips `dump_csv_files`. |

## ✅ Verification Plan

- **Manual Test**: Run `perl mysqltuner.pl --host 127.0.0.1` (or local equivalent) and verify no `0/` directory exists.
- **Automated Test**: Create a test script `tests/issue_dumpdir_0.t` that executes the script without the option and checks for the directory.
