---
description: Run MySQLTuner tests against multiple database configurations
---

# 🧪 Run Multi-DB Tests

This workflow automates the execution of `mysqltuner.pl` against various database versions using Docker environments.

## Prerequisite

- Docker and Docker Compose installed
- `make` installed
- https://github.com/jmrenouard/multi-db-docker-env
- https://github.com/jmrenouard/test_db

## Steps

1. **Run the test script**
// turbo

```bash
bash build/test_envs.sh mysql84 mariadb1011
```

> [!NOTE]
> You can pass specific configurations as arguments to the script.
> Example: `bash build/test_envs.sh mysql57 mariadb106 percona80`

1. **Check the results**
The reports are generated in the `examples/` directory, organized by date and configuration name.

- `report.txt`: Summary of the test run.
- `mysqltuner_output.txt`: Full output from MySQLTuner.
- `execution.log`: Standard output/error from the run.

1. **Cleanup**
The script automatically stops the containers, but you can manually ensure everything is clean:

```bash
cd vendor/multi-db-docker-env && make stop
```