# Specification: Perltidy Integration in Release Preflight

## Goal

Ensure that `mysqltuner.pl` is always properly formatted before a release is triggered. This will prevent "noisy" commits in the future and maintain a consistent coding style.

## Requirements

1. **Automated Check**: The `/release-preflight` workflow must include a step to verify that `mysqltuner.pl` is tidy.
2. **Zero Tolerance**: If the file is not tidy, the preflight check must fail.
3. **Tooling Consistency**: Use the same `perltidy` configuration as the rest of the project (if any) or default settings if none specified.
4. **Developer Experience**: Provide a clear command to fix the formatting if the check fails.

## User Scenarios

### Scenario 1: Tidy Script

A developer runs `/release-preflight`. The `perltidy` check passes, and they can proceed with the release.

### Scenario 2: Untidy Script

A developer runs `/release-preflight` after making manual formatting changes. The check fails, alerting the developer and suggesting `make tidy` to fix it.

## Technical Details

- Command for checking: `perltidy -st mysqltuner.pl | diff -q - mysqltuner.pl` (returns exit code 1 if different).
- Integrated into `.agent/workflows/release-preflight.md`.
- (Optional) New `Makefile` target `check-tidy` for easier local verification.
