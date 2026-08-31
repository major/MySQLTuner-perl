"""
Unit tests for build.issue_triage.infra_metric_parser
"""

import unittest
from build.issue_triage.infra_metric_parser import InfraMetricParser


class TestInfraMetricParser(unittest.TestCase):
    def test_parse_standard_linux_host(self):
        text = """
MemTotal: 65912400 kB
SwapTotal: 8388608 kB
SwapUsed: 0 kB
cpu cores: 16
load average: 1.25
"""
        metrics = InfraMetricParser.parse_infra_text(text)
        self.assertAlmostEqual(metrics.total_ram_bytes, 65912400 * 1024)
        self.assertEqual(metrics.total_swap_bytes, 8388608 * 1024)
        self.assertEqual(metrics.cpu_cores, 16)
        self.assertEqual(metrics.load_avg_1m, 1.25)
        self.assertFalse(metrics.is_container)

    def test_parse_docker_container(self):
        text = """
MySQLTuner called with: perl mysqltuner.pl --container
cgroup memory limit: 8G
Physical RAM: 64G
"""
        metrics = InfraMetricParser.parse_infra_text(text)
        self.assertTrue(metrics.is_container)
        self.assertEqual(metrics.cgroup_memory_limit_bytes, 8 * 1024 ** 3)
        self.assertEqual(metrics.total_ram_bytes, 64 * 1024 ** 3)


if __name__ == "__main__":
    unittest.main()
