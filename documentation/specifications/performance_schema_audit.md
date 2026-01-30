# Specification: Performance Schema Audit Logic

## Goal

Automatically detect and report if `performance_schema` is disabled during laboratory audits.

## Scenario

- **Test Case**: Laboratory execution on MariaDB or MySQL versions that support Performance Schema.
- **Evidence**: `execution.log` contains `✘ Performance_schema should be activated.`.
- **Action**: Add a new entry to `POTENTIAL_ISSUES` highlighting the lack of Performance Schema, which affects diagnostics.

## Rules

1. Audit the `execution.log` after each test run.
2. Search for the string `✘ Performance_schema should be activated.`.
3. If found, add to `POTENTIAL_ISSUES` under `Logic Anomalies`.
