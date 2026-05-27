---
test_file: tests/test_vulnerabilities.t
---
# Specification: Regex Robustness for Minor and Micro Releases

## Goal
Refactor version parsing regexes in version comparison helpers to more resiliently handle vendor-specific non-standard trailing strings (like alpha/beta/RC releases or custom build metadata) without triggering uninitialized warnings or incorrect comparisons.

## Requirements
1. **Robust Version Extract**: Upgrade regexes parsing the MySQL/MariaDB version string to safely match major, minor, and micro fields even when followed by non-numeric suffixes (e.g. `10.5.15-MariaDB-beta`, `8.4.0-alpha`, `11.4.1-rc1`, `8.0.35+build123`).
2. **Definedness Protection**: Ensure helper functions `mysql_version_eq()`, `mysql_version_ge()`, and `mysql_version_le()` explicitly guard against undefined version inputs or empty values, defaulting parsed components to `0` where necessary to avoid Perl runtime "Use of uninitialized value" warnings.
3. **No CPAN Dependency**: The refactoring must rely entirely on core Perl regex features and logical OR (`//`) defaults to keep `mysqltuner.pl` zero-dependency.

## Implementation Details
- Refactored regex: `/^(\d+)(?:\.(\d+))?(?:\.(\d+))?/` replaces the legacy `/^(\d+)(?:\.(\d+)|)(?:\.(\d+)|)/` in version parsing.
- Version components default assignment:
  ```perl
  my ($v_maj, $v_min, $v_mic) = $myvar{'version'} =~ /^(\d+)(?:\.(\d+))?(?:\.(\d+))?/;
  $v_maj //= 0;
  $v_min //= 0;
  $v_mic //= 0;
  ```

## Verification
- Parameterized test cases in `tests/test_vulnerabilities.t` verify matching for suffix formats (e.g. `10.11.5-MariaDB-log`, `11.4.1-rc1`, `8.4.0-alpha`, `8.0.35+build123`, `9.7-beta`).
- The entire unit test suite must run clean of "uninitialized value" warnings originating from the comparison subroutines.
