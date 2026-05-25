# MySQLTuner Commit and Release Process Guide

This document describes the mandatory workflow for committing changes and releasing new versions of MySQLTuner. Following this process ensures quality, formatting consistency, version integrity, and metadata compliance.

---

## 🛠️ 1. Commit Process

Every contribution to MySQLTuner must pass through a strict formatting, code generation, testing, and commit linting pipeline before being pushed.

### Step 1.1: Development Branching
All changes (features, bug fixes, chore, etc.) MUST be done in a dedicated Git branch separated from `master`. Committing directly to the `master` branch is strictly prohibited.

### Step 1.2: Code Formatting
Ensure that `mysqltuner.pl` matches the project formatting standard:
```bash
make tidy
```
*Behind the scenes*: This formats the code with `perltidy` using the project's config [.perltidy](file:///.perltidy) and cleans up file line endings with `dos2unix`.

To check if the formatting is correct without modifying the file:
```bash
make check-tidy
```

### Step 1.3: Generate Required Assets
If your changes affect CLI options, documentation, vulnerability lists, or support metadata, run the appropriate generators before committing:
*   **Documentation (USAGE.md)**: Rebuild the markdown usage guide from the Perl POD:
    ```bash
    make generate_usage
    ```
*   **Features List (FEATURES.md)**: Re-extract subroutines list:
    ```bash
    make generate_features
    ```
*   **CVE Vulnerabilities (vulnerabilities.csv)**: Fetch the latest security vulnerability definitions:
    ```bash
    make generate_cve
    ```
*   **End-of-Life Support Files (mysql_support.md, mariadb_support.md)**: Re-extract MySQL and MariaDB EOL dates:
    ```bash
    make generate_eof_files
    ```
*   **Current Version File (CURRENT_VERSION.txt)**: Keep the version file in sync:
    ```bash
    make generate_version_file
    ```

### Step 1.4: Run Automated Tests
Validate your changes locally using both unit tests and multi-database lab testing:
1.  **Unit & Regression Tests**:
    ```bash
    make unit-tests
    # or
    prove -r tests/ # (or perl build/audit_tests.pl)
    ```
2.  **Laboratory Tests (Docker)**:
    Ensure code executes correctly across multiple database versions (MySQL, MariaDB, Percona Server):
    ```bash
    make test
    # or run all environments
    make test-all
    ```

### Step 1.5: Commit via Conventional Commits
All commits must follow the standard [Conventional Commits](https://www.conventionalcommits.org/) specification:
*   **Allowed Types**: `feat`, `fix`, `chore`, `docs`, `perf`, `refactor`, `style`, `test`, `ci`
*   **Format**: `<type>(<scope>): <short summary>` followed by optional body/footer.
*   **Interactive Tool**: To guarantee compliance, commit using:
    ```bash
    npm run commit
    # or
    git cz
    ```

### Step 1.6: Commit Hooks Enforcement
Husky enforces validation at commit time:
*   **`pre-commit` Hook**: Automatically triggers `npm test` (`prove tests/*.t`). If unit tests fail, the commit is blocked.
*   **`commit-msg` Hook**: Validates the commit message structure against Conventional Commit rules using `commitlint`.

---

## 🚀 2. Release Process

The release lifecycle is governed by automated pre-flight checks and note generators to guarantee stability and release integrity.

### Step 2.1: Open a Release Branch
Cut a release branch named after the target version (e.g., `v2.8.42`):
```bash
git checkout -b vX.XX.XX
```

### Step 2.2: Synchronize Version Numbers
Ensure the target version is synchronized across all of the following locations:
1.  [CURRENT_VERSION.txt](file:///CURRENT_VERSION.txt)
2.  [mysqltuner.pl](file:///mysqltuner.pl) header (`# mysqltuner.pl - Version X.XX.XX`)
3.  [mysqltuner.pl](file:///mysqltuner.pl) internal variable (`our $tunerversion = "X.XX.XX"`)
4.  [mysqltuner.pl](file:///mysqltuner.pl) POD Name (`MySQLTuner X.XX.XX - MySQL High Performance`)
5.  [mysqltuner.pl](file:///mysqltuner.pl) POD Version (`Version X.XX.XX`)
6.  [Changelog](file:///Changelog) latest version header line (`X.XX.XX YYYY-MM-DD`)

To update version strings automatically across the codebase, use one of:
```bash
make increment_sub_version   # Bumps micro/sub version (e.g. 2.8.41 -> 2.8.42)
make increment_minor_version # Bumps minor version (e.g. 2.8.41 -> 2.9.0)
make increment_major_version # Bumps major version (e.g. 2.8.41 -> 3.0.0)
```

### Step 2.3: Update the Changelog & Generate Release Notes
1.  Add detailed bullet points in [Changelog](file:///Changelog) under the new version header, categorized by Conventional Commit types (`chore`, `feat`, `fix`, `test`, `ci`, etc.).
2.  Run the `/release-notes-gen` workflow (or script directly) to analyze the changelog, delta indicator metrics, and generate/update the corresponding release notes file:
    ```bash
    python3 build/release_gen.py
    ```
    *Behind the scenes*: This compiles the release summary, diagnostic growth statistics, commit differences, and CLI modifications into [releases/](file:///releases/) (e.g., `releases/v2.8.42.md`).

### Step 2.4: Execute Release Preflight Checks
Run the preflight checks to guarantee zero configuration mismatch and 100% compliance:
```bash
/release-preflight
```
*Behind the scenes*: This workflow:
1.  Verifies version consistency across files (via [tests/version_consistency.t](file:///tests/version_consistency.t)).
2.  Verifies that release notes exist in `releases/v[VERSION].md`.
3.  Checks that all commit messages follow conventional commits since the last tag.
4.  Checks project documentation formatting and metadata compliance.
5.  Validates `mysqltuner.pl` code formatting (`make check-tidy`).
6.  Runs the smoke test suite (`make test`).

### Step 2.5: Tag and Push (Unified Release Manager)
The final tag and push sequences are automated by the `/release-manager` workflow:
1.  Verify you are on the release branch.
2.  Commit all synchronized documentation and release notes.
3.  Perform release tagging:
    ```bash
    git tag -a vX.XX.XX -m "Release X.XX.XX" -m "Release notes contents..."
    ```
4.  Push the branch and release tag:
    ```bash
    git push origin vX.XX.XX
    git push origin refs/tags/vX.XX.XX
    ```
5.  Merge back into `master` and ensure tags are force pushed to origin to sync the workspace.
