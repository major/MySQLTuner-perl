# Specification: Performance Schema Observability Warning

## Goal

Improve user awareness of observability gaps when `performance_schema` is disabled.

## Requirements

1. Detect if `performance_schema` is OFF.
2. If OFF, provide a clear warning mentioning "observability issue".
3. Recommend enabling it for better diagnostics.

## Proposed Changes

### `mysqltuner.pl`

- Modify `sub mysql_pfs` to update the warning and recommendation text.

## User Scenarios

- **Scenario 1**: User runs MySQLTuner on a server where `performance_schema` is OFF.
  - **Result**: The "Performance schema" section shows a failure message including "(observability issue)".
  - **Recommendation**: "Performance schema should be activated for better diagnostics and observability" is added to the general recommendations.
