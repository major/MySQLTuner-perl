# Specification - Performance Schema `Error Log` Analysis

## 🧠 Rationale

Traditional `error log` analysis requires file system access, which is often restricted or complex in containerized/cloud environments. Modern MySQL/MariaDB versions expose `error logs` via the `performance_schema.error_log` table, allowing for structured, SQL-based diagnostic ingestion.

## User Scenarios

- **Scenario 1**: A user runs MySQLTuner on a remote RDS instance where they cannot access the physical log files. MySQLTuner detects the `error_log` table and performs analysis via SQL.
- **Scenario 2**: A containerized MySQL environment (Docker) has logs redirected to stdout. MySQLTuner uses the Performance Schema table to provide tuning advice based on recent boot-up `errors` and deadlocks.

## User Stories

| Title | Priority | Description | Rationale | Test Case |
| :--- | :--- | :--- | :--- | :--- |
| Table Detection | P1 | As a script, I want to check for `performance_schema.error_log`. | Ensure the feature only runs where supported. | GIVEN a MySQL 8.0 server, WHEN script connects, THEN it detects the table availability. |
| Log Ingestion | P1 | As a diagnostic engine, I want to count and fetch rows from `error_log`. | Use the table as a source for existing log parsing logic. | GIVEN 100 entries in `error_log`, WHEN script runs, THEN it captures all entries for analysis. |
| Aggregation Support | P2 | As an auditor, I want to see aggregated `error` counts (deadlocks, timeouts). | Provide quantitative evidence for recommendations. | GIVEN multiple deadlocks in the table, WHEN script finishes, THEN it reports "Detected N deadlocks". |

## Technical Implementation Details

- **Detection Query**: `SELECT 1 FROM information_schema.tables WHERE table_schema='performance_schema' AND table_name='error_log' LIMIT 1`
- **Ingestion Query**: `SELECT LOGGED, THREAD_ID, PRIO, SUBSYSTEM, ERROR_CODE, DATA FROM performance_schema.error_log`
- **Fallback**: If the table is empty or doesn't exist, fall back to `--server-log` or skip log analysis.

## Verification

- Validate against MySQL 8.0.34+ (where `error_log` is stable).
- Validate against MariaDB 10.6+ (check for equivalent table or plugin).
