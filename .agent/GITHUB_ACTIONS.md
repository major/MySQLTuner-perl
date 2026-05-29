# GitHub Actions CI/CD Workflows

This document outlines all automated GitHub Actions workflows configured in [.github/workflows/](file:///MySQLTuner-perl/.github/workflows/) for the MySQLTuner-perl project, specifying their triggers, jobs, and execution objectives.

---

## 🛠️ GitHub Actions Workflows Reference

| Workflow File | Purpose | Triggers | Key Jobs / Steps |
| :--- | :--- | :--- | :--- |
| [pull_request.yml](file:///MySQLTuner-perl/.github/workflows/pull_request.yml) | **Core CI Pipeline**: Runs compliance sentinel, EOL synchronization, and full unit test suite. | Push (all branches), PR (all branches) | `test_help` (MySQL 5.7 & 8.0), `test_with_empty_db`, `unit_tests` (compliance check, EOL sync check, and unit tests via `make unit-tests`). |
| [docker_publish.yml](file:///MySQLTuner-perl/.github/workflows/docker_publish.yml) | **Docker Image Publisher**: Builds, tags, and pushes multi-arch images to Docker Hub. | Tag Push (`v*`) | `build-and-push` (using docker buildx for multi-architecture platforms, tags `latest` and `v[VERSION]`). |
| [publish_release.yml](file:///MySQLTuner-perl/.github/workflows/publish_release.yml) | **Release Packager**: Packages release tarballs/zips and creates draft/published GitHub releases. | Tag Push (`v*`) | `create_release` (Builds checksums, uploads compiled release assets, drafts GitHub release notes). |
| [generate_mysql_examples.yml](file:///MySQLTuner-perl/.github/workflows/generate_mysql_examples.yml) | **MySQL Lab Generator**: Spawns integration tests on supported MySQL engines to update reports in `examples/`. | Workflow Dispatch, Scheduled Cron | `run_mysql_lab` (Spawns MySQL instances, runs integration scenarios, commits generated reports). |
| [generate_mariadb_examples.yml](file:///MySQLTuner-perl/.github/workflows/generate_mariadb_examples.yml) | **MariaDB Lab Generator**: Spawns integration tests on supported MariaDB engines to update reports in `examples/`. | Workflow Dispatch, Scheduled Cron | `run_mariadb_lab` (Spawns MariaDB instances, runs integration scenarios, commits generated reports). |
| [run_mt_with_db.yml](file:///MySQLTuner-perl/.github/workflows/run_mt_with_db.yml) | **E2E Container Integrator**: Runs E2E verifications against active MySQL/MariaDB container stacks. | Push, PR | `e2e_tests` (Sets up test databases, runs E2E scenarios, verifies health scores). |
| [codeql.yml](file:///MySQLTuner-perl/.github/workflows/codeql.yml) | **Security Scanner**: CodeQL analysis to scan Python, JavaScript, and shell files for security vulnerabilities. | Push (master), PR (master), Scheduled | `analyze` (Initializes CodeQL, autobuilds sources, performs static analysis, uploads findings). |
| [project-update.yml](file:///MySQLTuner-perl/.github/workflows/project-update.yml) | **Vulnerabilities Database Sync**: Checks for updates to the vulnerabilities list and opens automated PRs. | Scheduled Cron, Workflow Dispatch | `sync-cve` (Queries security databases, updates CVE listings, creates automated PRs). |
| [lts_autobump.yml](file:///MySQLTuner-perl/.github/workflows/lts_autobump.yml) | **LTS API Auto-Bumping Utility**: Periodically queries endoflife.date APIs, patches mysqltuner.pl and test files, and submits Git PRs. | Scheduled Cron, Workflow Dispatch | `lts-autobump` (Queries EOL, checks cycle mismatches, patches source files, and creates pull requests). |

---

## 🏃 Workflow Job Details

### 1. Continuous Integration (`pull_request.yml`)
Runs compile-time checks, compliance checks, EOL mapping validation, and the unit test suite on every change.
- **Triggers**: On pull requests and pushes to any branch.
- **Verification Gates**:
  1. `test_help`: Verifies `mysqltuner.pl --help` does not emit syntax or uninitialized errors.
  2. `test_with_empty_db`: Verifies execution output on standard empty MySQL containers is warning-free.
  3. `unit_tests`: Runs:
     - compliance sentinels (`perl build/check_compliance.pl`)
     - EOL sync checking (`perl build/sync_eol_dates.pl`)
     - unit test runner (`make unit-tests`)

### 2. Docker Image Publication (`docker_publish.yml`)
Publishes official docker images to Docker Hub.
- **Triggers**: On tags matching `v*`.
- **Target Images**: `jmrenouard/mysqltuner:latest` and `jmrenouard/mysqltuner:v[VERSION]`.

### 3. Release Publication (`publish_release.yml`)
Compiles releases, signs checksums, and attaches compiled assets to GitHub Releases.
- **Triggers**: On tags matching `v*`.
- **Action Items**: Packaged tarballs and zip releases, uploaded to the GitHub release page.

### 4. Lab Examples Generation (`generate_mysql_examples.yml` & `generate_mariadb_examples.yml`)
Keeps laboratory output reports in `examples/` directory up-to-date.
- **Triggers**: Nightly cron schedules or manual triggering.
- **Action Items**: Automates container startup, database injection, execution, reports consolidation, and commits updates to `examples/`.

### 5. CodeQL Analysis (`codeql.yml`)
Ensures no insecure coding practices or high-severity vulnerabilities are introduced in Python/JS scripts.
- **Triggers**: Push/PRs to `master` and weekly security crons.
- **Action Items**: Full static analysis, pushing findings directly to GitHub Security dashboard.

### 6. LTS API Auto-Bumper (`lts_autobump.yml`)
Queries `endoflife.date` APIs weekly, updates the LTS validation logic inside `mysqltuner.pl`, adjusts test suites, and opens an automated PR when a mismatch is found.
- **Triggers**: Weekly cron schedules or manually via workflow dispatch.
- **Action Items**: Runs `perl build/lts_autobump.pl` and uses `peter-evans/create-pull-request` to submit updates.

