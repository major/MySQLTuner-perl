# MySQLTuner-perl Project Rules

## Core Constitution
Make `mysqltuner.pl` the most stable, portable, and reliable performance tuning advisor for MySQL, MariaDB, and Percona Server.

### Key Pillars
- **Production Stability**: Every recommendation must be safe for production environments.
- **Single-File Architecture**: Strict enforcement of a single-file structure. Modules or splitting are prohibited.
- **Zero-Dependency Portability**: The script must remain self-contained and executable on any server with a base Perl installation (Core modules only).
- **Universal Compatibility**: Support the widest possible range of MySQL-compatible versions (Legacy 5.5 to Modern 11.x).
- **Regression Limit**: Proactively identify and prevent regressions through exhaustive automated testing.
- **Release Integrity**: Guarantee artifact consistency, tag synchronization, and multi-version validation through formal release management.

## Execution Rules & Constraints
1. **SINGLE FILE**: Splitting `mysqltuner.pl` into modules is **strictly prohibited**.
2. **NON-REGRESSION**: Deleting existing code is **prohibited** without relocation or commenting out.
3. **TDD MANDATORY**: Use a TDD approach. Validate solutions by creating test cases before final submission.
4. **SAFE COMMANDS**: Always use absolute paths. Monitor every command for `exit code 0`.
5. **CREDENTIAL HYGIENE**: NEVER hardcode credentials.
6. **VERSION CONSISTENCY & SYNCHRONIZATION**: Version numbers follow strict incremental semantic versioning (no irregular bumps). Version numbers MUST be synchronized across `CURRENT_VERSION.txt`, `Changelog`, `releases/v[VERSION].md`, and all occurrences within `mysqltuner.pl` (Header, internal variable `$VERSION`, and POD documentation) before any release.
7. **CONVENTIONAL COMMITS & CENTRALIZED CHANGELOG**: All commit messages MUST follow the [Conventional Commits](https://www.conventionalcommits.org/) specification (`feat:`, `fix:`, `chore:`, `docs:`, `perf:`, `test:`, `ci:`), enforced via `@commitlint/cz-commitlint` and pre-commit hooks (`npm run commit` / `git cz`). Every change (including tests, CI, and docs) MUST be traced in the root `Changelog` file, categorized and ordered by impact type (`chore`, `feat`, `fix`, `test`, `ci`).
8. **AUTOMATED RELEASE NOTES**: Technical release notes (`releases/v[VERSION].md`) MUST be generated simultaneously with `Changelog` updates for every version release, containing an executive summary, linked issues/PRs, features, fixes, and test highlights.
9. **BRANCHING & SYNCHRONIZED TAGGING**: Direct commits to `master` are strictly prohibited. ALL work MUST be done in dedicated feature/release branches. Every release bump MUST create an explicit `vX.Y.Z` Git tag force-pushed to origin via the `/release-manager` workflow, guaranteeing 100% synchronization between GitHub Releases and Git history.

## Best Practices
1. **Multi-Version Validation**: Test diagnostic logic changes against at least one "Legacy" version (e.g. MySQL 8.0) and one "Modern" version (e.g. MariaDB 11.4).
2. **System Call Resilience**: Every external command MUST check for binary existence and handle non-zero exit codes. Use `execute_system_command`.
3. **"Zero-Dependency" CPAN Policy**: Use ONLY Perl "Core" modules.
4. **Audit Trail**: Every recommendation MUST be documented in code with a comment pointing to official documentation.
5. **Memory-Efficient Parsing**: Process logs line-by-line; NEVER load large files into memory.
6. **SQL Modeling**: Use the `Modeling` array to collect schema design findings (naming, constraints, data types).

