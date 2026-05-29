---
test_file: tests/test_vulnerabilities.t
---
# Specification: Automated EOL Date Synchronization

## Goal
Develop an automated synchronization script to query endoflife.date APIs during CI workflows to automatically audit and flag outdated database versions in the script check routines when new releases occur.

## Requirements & User Stories
1. **API Integration**: Query the active releases from `https://endoflife.date/api/mysql.json` and `https://endoflife.date/api/mariadb.json`.
2. **Version Auditing**: Compare EOL database versions from the API with those listed as supported LTS versions inside the `validate_mysql_version()` subroutine of `mysqltuner.pl`.
3. **Legacy Whitelisting**: Support a whitelist for recently EOL-ed legacy releases (like MySQL 8.0) that are still officially kept as supported in the tuner.
4. **CI Integration**: Automatically execute as part of the GitHub Actions CI pipeline on every push and pull request.
5. **Fail-safe offline mode**: Exit gracefully with a warning (exit code `0`) if offline or during local network issues to prevent blocking local development, but fail the CI workflow (exit code `1`) if there is an actual version mismatch when the API is accessible.

## Implementation Details
- Script location: `build/sync_eol_dates.pl`
- Relies only on Perl core modules (`HTTP::Tiny` and `JSON::PP`) to preserve the zero external dependency architecture.
- Extracts `mysql_version_eq()` parameters inside the main script using regex parsing.

## Verification
- Run `perl build/sync_eol_dates.pl` directly and verify output.
- Check exit codes: `0` on match/offline, `1` on mismatch.
