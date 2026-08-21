"""
Multi-DB Docker Scenario Generator for Issue Reproduction
"""

from __future__ import annotations

import os
from typing import Dict, Any, Optional
from build.issue_triage.models import GitHubIssueRecord


class DockerScenarioGenerator:
    DOCKER_IMAGE_MAP = {
        "MySQL_8.4": "mysql:8.4.0",
        "MySQL_8.0": "mysql:8.0.36",
        "MySQL_5.7": "mysql:5.7.44",
        "MySQL_9.0": "mysql:9.0.1",
        "MariaDB_11.4": "mariadb:11.4",
        "MariaDB_10.11": "mariadb:10.11",
        "MariaDB_10.5": "mariadb:10.5",
        "Percona_8.0": "percona:8.0",
    }

    @classmethod
    def get_image_for_issue(cls, issue: GitHubIssueRecord) -> str:
        metrics = issue.extracted_metrics
        engine = metrics.db_engine.value if metrics else "MySQL"
        major = 8
        minor = 4
        if metrics and metrics.db_version_normalized:
            parts = [int(p) for p in metrics.db_version_normalized.split(".") if p.isdigit()]
            if len(parts) >= 2:
                major, minor = parts[0], parts[1]

        key = f"{engine}_{major}.{minor}"
        return cls.DOCKER_IMAGE_MAP.get(key, "mysql:8.4.0")

    @classmethod
    def generate_reproduce_script(cls, issue: GitHubIssueRecord) -> str:
        image = cls.get_image_for_issue(issue)
        container_name = f"mysqltuner_issue_{issue.number}"
        
        # Build cnf content
        cnf_lines = ["[mysqld]"]
        if issue.extracted_metrics and issue.extracted_metrics.variables:
            for k, v in issue.extracted_metrics.variables.items():
                cnf_lines.append(f"{k} = {v}")
        else:
            cnf_lines.append("innodb_buffer_pool_size = 1G")
        cnf_content = "\\n".join(cnf_lines)

        script = f"""#!/usr/bin/env bash
# ==============================================================================
# Reproduction Script for Issue #{issue.number} - {issue.title}
# Target Engine / Version: {image}
# ==============================================================================
set -euo pipefail

CONTAINER_NAME="{container_name}"
IMAGE="{image}"
PORT="3308"

echo "==> 1. Cleaning up previous containers..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "==> 2. Starting container $CONTAINER_NAME ($IMAGE)..."
docker run -d \\
  --name "$CONTAINER_NAME" \\
  -p "$PORT:3306" \\
  -e MYSQL_ROOT_PASSWORD=secret_pass \\
  -e MARIADB_ROOT_PASSWORD=secret_pass \\
  "$IMAGE"

echo "==> 3. Waiting for database readiness..."
sleep 15

echo "==> 4. Injecting custom configuration..."
docker exec -i "$CONTAINER_NAME" bash -c 'printf "{cnf_content}\\n" > /etc/mysql/conf.d/issue.cnf'

echo "==> 5. Running MySQLTuner in 3 required modes (Standard, Container, Dumpdir)..."
echo "--- Mode 1: Standard ---"
perl mysqltuner.pl --host=127.0.0.1 --port="$PORT" --user=root --pass=secret_pass --verbose

echo "--- Mode 2: Container Mode ---"
perl mysqltuner.pl --container="$CONTAINER_NAME" --verbose

echo "--- Mode 3: Dumpdir Mode ---"
mkdir -p dumps
perl mysqltuner.pl --host=127.0.0.1 --port="$PORT" --user=root --pass=secret_pass --dumpdir=dumps --verbose

echo "==> 6. Teardown..."
docker rm -f "$CONTAINER_NAME"
echo "==> Reproduction completed successfully."
"""
        return script
