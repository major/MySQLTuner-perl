"""
Unit tests for build.issue_triage.mysqltuner_output_parser
"""

import unittest
from build.issue_triage.mysqltuner_output_parser import MySQLTunerOutputParser
from build.issue_triage.models import DatabaseEngineType


class TestMySQLTunerOutputParser(unittest.TestCase):
    def test_parse_standard_report(self):
        sample_output = """
 >> MySQLTuner 2.9.0 - Major Hayden <major@mhtx.net>
 >> High Performance MySQL tuning script
 >> Currently running supported MySQL version 8.4.0-LTS
[--] Physical RAM     : 31.2G
[--] Max MySQL memory : 14.5G
[--] Percentage of RAM: 46.47 %
[OK] Currently running supported MySQL version 8.4.0-LTS
[OK] Operating on 64-bit architecture
[!!] Temporary tables created on disk: 25% (5K on disk / 20K total)
[!!] Total fragmented tables: 14

-------- Recommendations -----------------------------------------------------
General recommendations:
    Run OPTIMIZE TABLE to defragment tables for rows.
Variables to adjust:
    tmp_table_size (> 64M)
    max_heap_table_size (> 64M)
    innodb_buffer_pool_size (>= 20G)
"""
        report = MySQLTunerOutputParser.parse_report_text(sample_output)
        self.assertEqual(report.mysqltuner_version, "2.9.0")
        self.assertIsNotNone(report.db_info)
        self.assertEqual(report.db_info.engine_type, DatabaseEngineType.MYSQL)
        self.assertEqual(report.db_info.major, 8)
        self.assertEqual(report.db_info.minor, 4)
        self.assertEqual(report.physical_ram_raw, "31.2G")
        self.assertEqual(report.max_mysql_ram_raw, "14.5G")
        self.assertAlmostEqual(report.ram_pct_of_system, 46.47)

        # Indicators
        self.assertGreaterEqual(len(report.indicators), 4)
        bad_indicators = [i for i in report.indicators if i.level == "BAD"]
        self.assertEqual(len(bad_indicators), 2)
        self.assertIn("Temporary tables", bad_indicators[0].message)

        # Variables to adjust
        self.assertIn("tmp_table_size", report.adjust_variables)
        self.assertIn("innodb_buffer_pool_size", report.adjust_variables)
        self.assertEqual(report.adjust_variables["innodb_buffer_pool_size"], ">= 20G")


if __name__ == "__main__":
    unittest.main()
