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
  - **Legacy**: MySQL 5.7
  - **Modern**: MariaDB 11.4+
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

## ✅ Verification

- Manual code review.
- Automated audit via `build/test_envs.sh`.
