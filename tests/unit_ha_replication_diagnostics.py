"""
Unit tests for build.issue_triage.ha_replication_diagnostics
"""

import unittest
from build.issue_triage.ha_replication_diagnostics import HAReplicationDiagnostics


class TestHAReplicationDiagnostics(unittest.TestCase):
    def test_galera_non_primary_split_brain(self):
        status = {
            "wsrep_on": 1,
            "wsrep_cluster_status": "Non-Primary",
            "wsrep_local_state_comment": "Donor/Desynced",
        }
        vars_ = {"wsrep_on": 1}
        findings = HAReplicationDiagnostics.diagnose_galera(status, vars_)
        self.assertEqual(len(findings), 2)
        self.assertEqual(findings[0].rule_id, "GALERA_SPLIT_BRAIN_01")
        self.assertEqual(findings[0].severity, "CRITICAL")

    def test_async_replication_broken_and_lagged(self):
        status = {
            "slave_io_running": "Yes",
            "slave_sql_running": "No",
            "seconds_behind_master": 600,
        }
        findings = HAReplicationDiagnostics.diagnose_async_replication(status, {})
        self.assertEqual(len(findings), 2)
        self.assertEqual(findings[0].rule_id, "REPLI_SQL_THREAD_01")
        self.assertEqual(findings[0].severity, "CRITICAL")
        self.assertEqual(findings[1].rule_id, "REPLI_LAG_01")
        self.assertEqual(findings[1].severity, "BAD")


if __name__ == "__main__":
    unittest.main()
