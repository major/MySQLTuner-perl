# Specification: Index Checks via Performance Schema

## Goal

Enhance `mysqltuner.pl` to provide actionable recommendations and modeling findings for unused and redundant indexes when `performance_schema` and `sys` schema are available.

## New Indicators

### 1. Unused Indexes

- **Source**: `sys.schema_unused_indexes`
- **Scope**: All user schemas (excluding `performance_schema`, `mysql`, `information_schema`, `sys`).
- **Action**:
  - Count the number of unused indexes.
  - If count > 0:
    - Add a recommendation to `@generalrec`: "Unused indexes found: X index(es) should be reviewed and potentially removed."
    - Add a modeling finding to `@modeling` with details for each unused index.
    - Print a summary in the CLI output.

### 2. Redundant Indexes

- **Source**: `sys.schema_redundant_indexes`
- **Scope**: All user schemas.
- **Action**:
  - Count the number of redundant indexes.
  - If count > 0:
    - Add a recommendation to `@generalrec`: "Redundant indexes found: X index(es) should be reviewed and potentially removed."
    - Add a modeling finding to `@modeling` with details for each redundant index.
    - Print a summary in the CLI output.

## Implementation Details

- These checks will be integrated into the `mysql_pfs` subroutine or a dedicated subroutine called from it.
- Ensure compatibility with MySQL 5.7+ and MariaDB (where `sys` schema is available).
- Use `select_array` to fetch data from `sys` schema views.
- Adhere to the project's single-file architecture.

## User Scenarios

- **Scenario 1**: `performance_schema` is OFF. No action taken (existing behavior).
- **Scenario 2**: `performance_schema` is ON but `sys` schema is missing. Recommendation to install `sys` schema (existing behavior).
- **Scenario 3**: `performance_schema` is ON and `sys` schema is present. New checks for unused and redundant indexes are performed, and findings are reported.
