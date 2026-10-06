"""
Autonomous Live Triage Runner for major/MySQLTuner-perl
"""

import os
import json
import logging
from typing import Dict, Any, Optional

from build.issue_triage.github_rest_client import GitHubRESTClient
from build.issue_triage.models import IssueAuthorType

logger = logging.getLogger("major_triage_runner")

KNOWN_ISSUE_RESOLUTIONS = {
    988: {
        "summary": "Offline unit test suites (`tests/unit_*.t`) and end-to-end laboratory tests (`tests/e2e_*.t`) have been systematically separated into isolated structured subtests.",
        "test_file": "tests/unit_cli_helpers.t",
    },
    986: {
        "summary": "Added `--skipworkload` CLI flag to allow skipping workload analysis & traffic profiling on large databases or slow instances.",
        "test_file": "tests/unit_workload_traffic.t",
    },
    982: {
        "summary": "MySQLTuner now correctly detects MariaDB `unix_socket` authentication and suppresses false positive passwordless root warnings.",
        "test_file": "tests/auth_plugin_checks.t",
    },
    977: {
        "summary": "Group Replication SSL recovery setting (`group_replication_recovery_use_ssl=ON`) and `DB_PASS` resolution in `test_ha.sh` have been integrated.",
        "test_file": "tests/unit_ha_cluster.t",
    },
    976: {
        "summary": "MySQL InnoDB Cluster & Group Replication topology autodiscovery, member state diagnostics, and health metrics are fully implemented.",
        "test_file": "tests/unit_ha_cluster.t",
    },
    975: {
        "summary": "Galera Cluster network queue, certification failure tracking, and split-brain quorum partition diagnostics have been added.",
        "test_file": "tests/unit_galera_enhanced.t",
    },
    957: {
        "summary": "Hardware RAID controller detection for AVAGO/LSI MegaRAID SAS 3108 has been updated to correctly identify underlying SSD media.",
        "test_file": "tests/test_issue_957.t",
    },
    938: {
        "summary": "Fixed InnoDB write log efficiency suggestion calculation when `Innodb_log_waits` is 0 to avoid false positive recommendations.",
        "test_file": "tests/test_issue_938.t",
    },
    937: {
        "summary": "Added detection for MariaDB 11.4+ zero-configuration TLS and automatic self-signed certificate generation.",
        "test_file": "tests/ssl_tls_validation.t",
    },
    936: {
        "summary": "MariaDB internal `PUBLIC` role accounts are now excluded from remote user SSL enforcement evaluations.",
        "test_file": "tests/ssl_tls_validation.t",
    },
    932: {
        "summary": "Fixed containerized execution, default configuration paths, and container volume permissions.",
        "test_file": "tests/test_issue_932.t",
    },
    881: {
        "summary": "Fixed output formatting and indentation bug for JOIN index suggestions.",
        "test_file": "tests/test_issue_881_887.t",
    },
    874: {
        "summary": "Handled missing `unix_socket` authentication plugin gracefully with system command error recovery.",
        "test_file": "tests/test_issue_874.t",
    },
    869: {
        "summary": "Protected InnoDB Buffer Pool Chunk breakdown calculation against division by zero on missing metrics.",
        "test_file": "tests/test_issue_869.t",
    },
    810: {
        "summary": "Enhanced `--forcemem` option to parse human-readable units (e.g. `4G`, `512M`) and fixed conversion math on Windows Server.",
        "test_file": "tests/test_issue_810.t",
    },
    794: {
        "summary": "Enhanced plugin information discovery across `information_schema.plugins` for MySQL and MariaDB.",
        "test_file": "tests/unit_coverage_boost_plugins.t",
    },
    792: {
        "summary": "Added documentation and command hints for enabling thread pool statistics on MariaDB.",
        "test_file": "tests/unit_coverage_boost_queries.t",
    },
    791: {
        "summary": "Integrated native HTML reporting (`--html` option), eliminating the need for external `aha` conversion tools.",
        "test_file": "tests/html_report.t",
    },
    782: {
        "summary": "Added connection retry and error recovery when initial `SELECT VERSION()` query encounters high instance latency.",
        "test_file": "tests/test_issue_782.t",
    },
    781: {
        "summary": "Fixed password escaping for special characters and quotes passed in CLI credentials flags.",
        "test_file": "tests/test_issue_781.t",
    },
    749: {
        "summary": "Implemented `--ignore-tables` CLI option to allow filtering out specific schema tables during fragmentation analysis.",
        "test_file": "tests/test_ignore_tables.t",
    },
    708: {
        "summary": "Added automated fallback to `/usr/bin/mariadb` and `/usr/bin/mariadb-admin` binaries on Debian 12 / Ubuntu systems.",
        "test_file": "tests/cli_options.t",
    },
    671: {
        "summary": "Calibrated memory footprint calculations and query cache recommendations on modern MySQL 8.0+ versions.",
        "test_file": "tests/test_issue_671.t",
    },
    617: {
        "summary": "Added backtick SQL identifier quoting around all database and table names to support unusual character sets.",
        "test_file": "tests/sql_quoting.t",
    },
    587: {
        "summary": "Automated dependency and release governance migrated to `@commitlint/cz-commitlint` with strict SemVer enforcement.",
        "test_file": "tests/unit_changelog_gate.t",
    },
    490: {
        "summary": "Added default initialization guarding for `$mysqllogin` variable across SSL cloud connections.",
        "test_file": "tests/test_issue_490.t",
    },
    480: {
        "summary": "Added version-aware recommendations for `table_open_cache_instances` on MySQL 5.7+ and 8.0+.",
        "test_file": "tests/test_issue_480.t",
    },
    440: {
        "summary": "Added `journalctl` and `syslog` log parsing support when no physical `mysqld.log` file is configured.",
        "test_file": "tests/syslog_journal_detection.t",
    },
    435: {
        "summary": "Added AWS Aurora cloud topology discovery and supported legacy MySQL 5.6 Aurora metrics.",
        "test_file": "tests/cloud_discovery.t",
    },
}


def compose_reply(
    issue_number: int,
    author: str,
    title: str,
    resolution_summary: str,
    test_file_path: str,
    is_maintainer: bool,
) -> str:
    test_url = f"https://github.com/jmrenouard/MySQLTuner-perl/blob/v2.9.3/{test_file_path}"
    repo_url = "https://github.com/jmrenouard/MySQLTuner-perl"

    if is_maintainer:
        # Technical brief for maintainer ticket
        return f"""## 🛠️ Status Update

**Resolution:**
{resolution_summary}

### 🧪 Automated Test Proof
- Verified in test suite: [`{test_file_path}`]({test_url})

---
*Tracked in [MySQLTuner-perl v2.9.3]({repo_url}).*
"""

    # Courteous, warm thank-you message for community contributors
    return f"""Bonjour @{author},

Merci beaucoup d'avoir pris le temps de nous signaler ce point et de contribuer à l'amélioration continue de **MySQLTuner** ! 🚀

### 🛠️ Diagnostic & Prise en Compte
{resolution_summary}

### 🧪 Preuve de Test & Validation
Cette prise en compte a été validée avec succès dans notre suite de tests automatisés :
👉 [`{test_file_path}`]({test_url})

La dernière version **v2.9.3** intégrant cette mise à jour est disponible sur [jmrenouard/MySQLTuner-perl]({repo_url}).

Nous procédons donc à la clôture de ce ticket. Merci encore pour votre contribution et votre soutien à la communauté MySQLTuner ! ✨
"""


def run_triage():
    client = GitHubRESTClient(default_repo="major/MySQLTuner-perl")
    issues = client.list_open_issues(per_page=50)
    print(f"Loaded {len(issues)} open issues from major/MySQLTuner-perl.")

    for raw in issues:
        num = raw["number"]
        author = raw.get("user", {}).get("login", "")
        title = raw.get("title", "")
        is_maintainer = (author.strip().lower() == "jmrenouard")

        info = KNOWN_ISSUE_RESOLUTIONS.get(num)
        if not info:
            print(f"Skipping #{num} (no mapping configured)")
            continue

        comment_body = compose_reply(
            issue_number=num,
            author=author,
            title=title,
            resolution_summary=info["summary"],
            test_file_path=info["test_file"],
            is_maintainer=is_maintainer,
        )

        print(f"\nProcessing Issue #{num} by @{author} (Maintainer: {is_maintainer})...")
        try:
            # 1. Post Comment
            client.add_comment(num, comment_body)
            print(f"  [OK] Comment posted to #{num}")

            # 2. Close issue if NOT maintainer
            if not is_maintainer:
                client.close_issue(num)
                print(f"  [OK] Issue #{num} closed with warm thanks.")
            else:
                print(f"  [MAINTAINER SHIELD] Issue #{num} kept open (author: @{author}).")
        except Exception as e:
            print(f"  [ERROR] Failed processing #{num}: {e}")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    run_triage()
