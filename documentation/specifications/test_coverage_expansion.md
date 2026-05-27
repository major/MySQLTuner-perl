---
test_file: tests/unit_system.t
---
# Specification: Test Coverage Expansion

## Goal
Expand unit test coverage for MySQLTuner-perl subroutines, targeting and resolving untested core subroutines (aiming to cross the >60% threshold).

## Requirements
1. **Target Subroutines**: Develop comprehensive unit tests covering key untested subroutines:
   - `check_architecture`
   - `mysql_views`, `mysql_routines`, `mysql_triggers`
   - `make_recommendations`
   - `close_outputfile`
   - `get_ssh_prefix`, `get_container_prefix`, `get_transport_prefix`
   - `build_mysql_connection_command`
   - `write_manifest_files`
2. **Environment Mocking**: Implement standard mocks for platform utilities, system commands, and directories (e.g. `POSIX::uname`, Windows OS identification, file handles, transport flags) to execute these routines deterministically in isolated unit environments.
3. **Assertions**: Verify outcomes (e.g. `%result` hash allocations, generated manifest logs, correctly formatted recommendations output) match expected behaviors.

## Implementation Details
- New test file: `tests/unit_system.t`
- Intercepts and tests formatting functions like `human_size`.
- Employs `File::Temp` for clean file/folder mocks during manifest generation checks.

## Verification
- Run `make unit-tests` (which executes `build/audit_tests.pl` to run and audit `prove -r tests/`).
- Subroutines tested metric in `POTENTIAL_ISSUES.md` updated to reflect the new coverage level (~61%).
