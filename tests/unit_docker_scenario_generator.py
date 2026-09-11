"""
Unit tests for build.issue_triage.docker_scenario_generator
"""

import unittest
from build.issue_triage.docker_scenario_generator import DockerScenarioGenerator
from build.issue_triage.models import (
    GitHubIssueRecord,
    IssueAuthorType,
    ExtractedMetrics,
    DatabaseEngineType,
)


class TestDockerScenarioGenerator(unittest.TestCase):
    def test_generate_reproduce_script(self):
        issue = GitHubIssueRecord(
            number=777,
            title="MariaDB 11.4 optimizer check",
            author="dba_user",
            author_type=IssueAuthorType.COMMUNITY_USER,
            created_at="2026-08-22T00:00:00Z",
            updated_at="2026-08-22T00:00:00Z",
            state="open",
            body="Sample body",
            extracted_metrics=ExtractedMetrics(
                db_engine=DatabaseEngineType.MARIADB,
                db_version_raw="11.4.2",
                db_version_normalized="11.4.2",
                variables={"table_open_cache": 2000},
            ),
        )
        script = DockerScenarioGenerator.generate_reproduce_script(issue)
        self.assertIn("mariadb:11.4", script)
        self.assertIn("mysqltuner_issue_777", script)
        self.assertIn("--container", script)
        self.assertIn("--dumpdir=dumps", script)


if __name__ == "__main__":
    unittest.main()
