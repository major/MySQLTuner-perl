---
trigger: always_on
description: Technical best practices and recommended internal patterns.
category: governance
---
# **4\. 🌟 CORE BEST PRACTICES**

## 🧠 Rationale

Beyond hard constraints, following established patterns ensures code durability, resilience, and consistent user experience across different platforms.

## 🛠️ Implementation

### 1. Multi-Version Validation

- Every diagnostic logic change MUST be tested against:
  - **Legacy**: MySQL 8.0+
  - **Modern**: MariaDB 11.4+
- **Example Generation**: Automated test reports in `examples/` MUST only be generated for "Supported" versions as defined in project support documentation (`mysql_support.md`, `mariadb_support.md`).
- Use `make test-it` for automated lab validation.

### 2. System Call Resilience

- Every external command (`sysctl`, `ps`, `free`, `mysql`) MUST:
  - Check for binary existence.
  - Handle non-zero exit codes.
  - Use `execute_system_command` to ensure transport abstraction.

### 3. "Zero-Dependency" CPAN Policy

- Use ONLY Perl "Core" modules.
- `mysqltuner.pl` must remain a single, copyable script executable on any server without CPAN installs.

### 4. Audit Trail (Advice Traceability)

- Every recommendation MUST be documented in code with a comment pointing to official documentation (MySQL/MariaDB KB).

### 5. Memory-Efficient Parsing

- Process logs line-by-line using `while` loops.
- NEVER load entire large files into memory.

### 6. Test Infrastructure Traceability

- All test runs MUST capture:
  - **Docker Logs** (`docker logs [id]`)
  - **Infrastructure events** (DB injection, startup)
  - **Reproducibility script**: Provide exact commands to replay the test.
  - **Capture level**: All test infrastructure logs (docker start, db injection, container logs, container inspect) MUST be captured and linked in HTML reports.

### 7. Unified Laboratory Reporting

- HTML reports MUST be self-sufficient and follow the standard structure:
  - **Horizontal Scenario Selector**: Support tripartite test cases (Standard, Container, Dumpdir).
  - **Embedded Logs**: Embed all relevant logs (Docker, DB injection, etc.).
  - **Reproduce Section**: Full sequence of commands to replay the test.
  - **Output Placement**: MySQLTuner output MUST be at the bottom for consolidated sharing.
- Testing MUST encompass 3 specific scenarios: Standard (`--verbose`), Container (`--verbose --container`), and Dumpdir (`--verbose --dumpdir=dumps`).
- The `examples/` directory MUST only retain the 10 most recent laboratory execution results to optimize storage.

### 8. Advanced Test Log Auditing

- Post-execution of any test suite (Standard, Container, Dumpdir), the `execution.log` MUST be audited.
- The auditor MUST look for:
  - Perl warnings (uninitialized values, deprecated syntax).
  - SQL execution failures ("FAIL Execute SQL").
  - Transport or connection errors.
  - Performance Schema status (search for "✘ Performance_schema should be activated.").
- Any anomaly discovered MUST be recorded in the `POTENTIAL_ISSUES` file at the project root for further investigation, including the path to the relevant `execution.log`.
- Cleanup `POTENTIAL_ISSUES` file as soon as the reported issue is handled, tested, or fixed.

### 9. SQL Modeling Findings

- The `Modeling` array in `mysqltuner.pl` MUST be used to collect schema design findings (naming, constraints, data types), while `@generalrec` remains for operational tuning.
- All modeling-related subroutines MUST push findings to both `@generalrec` (for CLI visibility) and `@modeling` (for structured HTML/JSON reporting).

### 10. Kernel Tuning in Containers

- Kernel tuning recommendations MUST be skipped in container mode or when running in Docker to avoid non-pertinent advice.

### 11. Release Integrity & Tagging

- Release workflows (via `/git-flow`) MUST force push tags to the origin at each release to ensure synchronization with GitHub.
- The `/git-flow` workflow MUST always be preceded by a successful `/release-preflight` execution.
- Only the Release Manager is authorized to decide when to increment version numbers, or incrementing occurs automatically after a `git-flow` commit.

### 12. Artifact Path Hygiene

- File links in artifacts MUST be cleaned up to remove workstation-specific absolute paths (e.g., replace `file:///home/jmren/GIT_REPOS/` with `file:///`).

## ✅ Verification

- Manual code review.
- Automated audit via `build/test_envs.sh`.
