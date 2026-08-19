# MySQLTuner-perl Testing & Quality Assurance Guide

MySQLTuner-perl enforces a strict Test-Driven Development (TDD) and multi-version regression validation lifecycle to guarantee zero-regression stability across MySQL, MariaDB, and Percona Server.

---

## 🧪 1. Unit & Regression Test Suite

The test harness uses Perl Core `Test::More` decomposed into focused subtests.

### Running the Full Test Suite:
```bash
# Recommended parallel execution (fast):
prove -j4 -r tests/

# Comprehensive audit gate with compile and SQL linting:
perl build/audit_tests.pl

# Via Makefile:
make unit-tests
```

### Key Test Suites Breakdown:
- `tests/version_consistency.t`: Validates 100% synchronization of version strings across header, variable, POD, Changelog, and Release Notes.
- `tests/cli_options.t` & `tests/cli_validation.t`: Validates CLI argument parsing, mutually exclusive flags, and parameter bounds.
- `tests/auth_plugin_checks.t`: Validates security classification for all MySQL/MariaDB authentication plugins.
- `tests/unit_galera_enhanced.t` & `tests/unit_galera_pxc.t`: Validates Galera Flow Control and split-brain checks.
- `tests/unit_ha_cluster.t`: Validates InnoDB Cluster and Group Replication status evaluations.
- `tests/unit_cvefile_fallback.t`: Validates local directory and distribution path fallback resolution.
- `tests/e2e_mcp_server.t`: Validates JSON-RPC 2.0 stdio communications and tool dispatching.

---

## 🔍 2. Static Code & SQL Linting

Before any commit or PR, static linters audit code formatting and query quality:
```bash
# Perltidy style formatting verification:
make check-tidy

# Static SQL syntax and keyword capitalization validation:
perl build/audit_tests.pl
```

---

## 🐳 3. Multi-DBMS Laboratory Testing (Docker)

The laboratory environment validates MySQLTuner against live, containerized database instances.

### Setup External Test Environments:
```bash
make vendor_setup
```

### Running Laboratory Tests:
```bash
# Run tests against default baseline (mysql84, mariadb1011, percona80):
make test

# Run tests against all supported database engines:
make test-all

# Run tests against a specific target container:
make test-container CONTAINER=mysql_test_84
```

### High Availability (HA) Cluster Laboratory:
```bash
# Run E2E tests across all HA topologies:
make test-ha

# Individual HA topology targets:
make test-ha-galera   # Galera Cluster 4
make test-ha-innodb   # MySQL InnoDB Cluster (Group Replication)
make test-ha-repli    # Primary-Replica GTID Replication
```

### AI Model Context Protocol (MCP) Laboratory:
```bash
# Run E2E test against live database via MCP server:
make test-mcp-e2e
```

---

## 📋 4. Standard Tripartite Test Scenarios

Every diagnostic logic change must be validated against the 3 core execution paradigms:
1. **Standard Host Mode**: `./mysqltuner.pl --verbose`
2. **Containerized Mode**: `./mysqltuner.pl --verbose --container [CONTAINER_NAME]`
3. **Dumpdir Offline Mode**: `./mysqltuner.pl --verbose --dumpdir=dumps/`

### Laboratory Log Audit:
```bash
# Audit execution logs for warnings, errors, or query anomalies:
make audit-logs
```

