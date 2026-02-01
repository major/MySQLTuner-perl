# Specification: Metadata-Driven CLI Options Refactor (Phase 6)

## Overview

This specification covers the enhancement of the CLI option parsing mechanism in `mysqltuner.pl` to achieve 100% synchronization between code, defaults, validation, and documentation.

## Goals

- **Centralized Validation**: Move validation logic from `setup_environment` into `%CLI_METADATA`.
- **Improved Validation API**: Support `regex` and `validate` (coderef) in metadata.
- **POD Synchronization**: Update the `pod2usage` call to avoid referencing non-existent sections and ensure `perldoc` remains a reliable secondary source of truth.
- **Dependency Management**: Support `implies` (e.g., `--feature` implies `--verbose`).
- **Standardized Defaults**: Ensure all defaults in metadata are the actual operational defaults.

## User Scenarios

- **Developer adds an option**: The developer only adds an entry to `%CLI_METADATA`. Help, defaults, and basic validation are automatically handled.
- **User provides invalid input**: The script catches invalid values (e.g., non-numeric port) during parsing and provides a clear error message.
- **User runs `perldoc`**: The user sees correct, up-to-date documentation that matches `--help`.

## Technical Requirements

- Use only Perl Core modules (`Getopt::Long`, `Pod::Usage`).
- Maintain single-file architecture.
- Zero regression on existing options.

## Proposed Changes

- Add `validate` (regex or coderef) to `%CLI_METADATA`.
- Add `implies` (hashref or arrayref) to `%CLI_METADATA`.
- Update `parse_cli_args` to:
  - Perform validation after `GetOptions`.
  - Apply implications.
- Update `show_help` if needed (already mostly metadata-driven).
- Clean up `setup_environment` by removing logic now handled by metadata.
- Correct `pod2usage` sections.
