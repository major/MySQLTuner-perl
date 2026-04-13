# Specification: MySQL 9.x Support

## Feature Name: MySQL 9.x Ecosystem Support

**Status**: Draft
**Created Date**: 2026-02-14

## Goal

Ensure `mysqltuner.pl` is fully compatible with MySQL 9.x, handling removed variables and new defaults.

## Key Changes in MySQL 9.x

### Removed Components

- `mysql_native_password` authentication plugin.
- Many deprecated system variables from 8.x.

### New Features to Support

- New performance_schema tables for monitoring.
- Updates to InnoDB defaults and internal structures.

## User Stories

| Title | Priority | Description | Rationale | Test Case |
| :--- | :--- | :--- | :--- | :--- |
| Version Detection | P1 | As a user, I want MySQLTuner to correctly recognize MySQL 9.x. | To ensure version-specific advice is correct. | GIVEN MySQL 9.0, WHEN I run MySQLTuner, THEN it identifies the version correctly. |
| Handle Removals | P1 | As a user, I want MySQLTuner to NOT try and use removed features. | To avoid SQL errors or crashes. | GIVEN MySQL 9.0, WHEN I run MySQLTuner, THEN it skips checks for `mysql_native_password`. |

## Implementation Plan

1. Update version detection logic in `mysqltuner.pl`.
2. Audit all existing checks for features removed in 9.x.
3. Add specific advice for 9.x performance optimizations.
