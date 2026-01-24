---
description: Run MySQLTuner tests against multiple database configurations
---

# 🧪 Run Multi-DB Tests

This workflow automates the execution of `mysqltuner.pl` against various database versions using Docker environments.

## Prerequisite

- Docker and Docker Compose installed
- `make` installed
- <https://github.com/jmrenouard/multi-db-docker-env>
- <https://github.com/jmrenouard/test_db>

## Steps

There are three modes available in the unified script:

### Mode 1: Lab (Multi-DB Docker Environment)

Executes tests against various DB versions with sample data.

```bash
bash build/test_envs.sh mysql84 mariadb1011
```

### Mode 2: Existing Container

Runs MySQLTuner against a running container.

```bash
bash build/test_envs.sh --existing-container my_db_container
# OR via Makefile
make test-container CONTAINER=my_db_container
```

### Mode 3: Remote Audit (SSH)

Performs a full audit on a remote host (transfers script, runs audit tools).

```bash
bash build/test_envs.sh --remote db-server.example.com --audit
# OR via Makefile
make audit HOST=db-server.example.com
```

1. **Check the results**
The reports are generated in the `examples/` directory, organized by date and target name.

- `report.html`: Comprehensive dashboard.
- `mysqltuner_output.txt`: Full output from MySQLTuner.
- `execution.log`: Standard output/error from the run.

1. **Cleanup**
The script automatically manages lab containers. For manual cleanup:

```bash
cd vendor/multi-db-docker-env && make stop
```
