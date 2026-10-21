"""
Unit tests for build.issue_triage.db_taxonomy
"""

import unittest
from build.issue_triage.db_taxonomy import DatabaseTaxonomyResolver
from build.issue_triage.models import DatabaseEngineType


class TestDatabaseTaxonomyResolver(unittest.TestCase):
    def test_mysql_8_4_lts(self):
        info = DatabaseTaxonomyResolver.resolve("8.4.0", "MySQL Community Server - GPL")
        self.assertEqual(info.engine_type, DatabaseEngineType.MYSQL)
        self.assertEqual(info.major, 8)
        self.assertEqual(info.minor, 4)
        self.assertEqual(info.patch, 0)
        self.assertEqual(info.release_type, "LTS")
        self.assertFalse(info.is_eol)

    def test_mysql_9_0_innovation(self):
        info = DatabaseTaxonomyResolver.resolve("9.0.1", "MySQL Community Server")
        self.assertEqual(info.engine_type, DatabaseEngineType.MYSQL)
        self.assertEqual(info.major, 9)
        self.assertEqual(info.minor, 0)
        self.assertEqual(info.release_type, "Innovation")
        self.assertFalse(info.is_eol)

    def test_mariadb_5_5_5_prefix(self):
        raw = "5.5.5-10.11.8-MariaDB-1:10.11.8+maria~ubu2204-log"
        info = DatabaseTaxonomyResolver.resolve(raw)
        self.assertEqual(info.engine_type, DatabaseEngineType.MARIADB)
        self.assertEqual(info.major, 10)
        self.assertEqual(info.minor, 11)
        self.assertEqual(info.patch, 8)
        self.assertEqual(info.normalized_version, "10.11.8")
        self.assertTrue(info.is_mariadb)
        self.assertEqual(info.release_type, "LTS")

    def test_percona_server_pxc(self):
        raw = "8.0.35-27.1-Percona XtraDB Cluster (GPL)"
        info = DatabaseTaxonomyResolver.resolve(raw, context_text="wsrep_cluster_name = prod_cluster")
        self.assertEqual(info.engine_type, DatabaseEngineType.PERCONA)
        self.assertTrue(info.is_percona)
        self.assertTrue(info.is_galera_pxc)
        self.assertEqual(info.major, 8)
        self.assertEqual(info.minor, 0)

    def test_aws_aurora_detection(self):
        info = DatabaseTaxonomyResolver.resolve("8.0.mysql_aurora.3.04.0", context_text="Running on AWS Aurora RDS cluster")
        self.assertEqual(info.engine_type, DatabaseEngineType.AURORA_MYSQL)
        self.assertTrue(info.is_cloud)
        self.assertEqual(info.cloud_provider, "AWS")

    def test_legacy_eol_mysql_5_7(self):
        info = DatabaseTaxonomyResolver.resolve("5.7.44")
        self.assertTrue(info.is_eol)
        self.assertEqual(info.release_type, "Legacy / EOL")


if __name__ == "__main__":
    unittest.main()
