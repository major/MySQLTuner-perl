---
trigger: explicit_call
description: Comprehensive test suite execution (Unit, Regression, and Multi-DB)
category: tool
---

# 🧪 Unified Test Orchestration

This workflow provides a single entry point for all testing activities, from local unit tests to industrial-grade multi-DB integration tests.

## 🧠 Rationale

Consistency and coverage are paramount. By unifying all testing entry points, we ensure that both core logic and multi-version compatibility are systematically verified following the **Testing Orchestration Skill** patterns.

## 🛠️ Implementation

### 1. Unit & Regression Tests (Local)

Execute the standard Perl test suite to verify core logic.

// turbo

```bash
# Using prove
prove -r tests/

# OR via Makefile
make unit-tests
```

### 2. Multi-DB Integration Tests (Docker)

Validate compatibility across multiple database versions using the tripartite scenario laboratoy.

// turbo

```bash
# Example: Run against MySQL 8.4 and MariaDB 11.4
bash build/test_envs.sh mysql84 mariadb114

# OR via Makefile
make test-it
```

### 3. Advanced Diagnostic & Audit Scenarios

#### Existing Container

```bash
bash build/test_envs.sh --existing-container <container_id>
# OR: make test-container CONTAINER=<container_id>
```

#### Remote Audit (SSH)

```bash
bash build/test_envs.sh --remote <host> --audit
# OR: make audit HOST=<host>
```

## ✅ Verification

Ensure all commands return an exit code of 0. Review reports in `examples/` for detailed multi-DB analysis results:

> [!NOTE]
> Automated example generation in `examples/` is limited to "Supported" versions of MySQL and MariaDB to ensure relevance and stability.

- `report.html`: Consolidated dashboard.
- `raw_mysqltuner.txt`: Complete analysis output.
- `execution.log`: Full system execution trace.
