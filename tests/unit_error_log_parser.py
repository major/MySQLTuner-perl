"""
Unit tests for build.issue_triage.error_log_parser
"""

import unittest
from build.issue_triage.error_log_parser import ErrorLogParser, ErrorEventType


class TestErrorLogParser(unittest.TestCase):
    def test_parse_deadlock_event(self):
        log_sample = "2026-08-20T10:15:30.123456Z 42 [ERROR] [MY-011925] [InnoDB] Deadlock found when trying to get lock; try restarting transaction"
        events = ErrorLogParser.parse_log_excerpt(log_sample)
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].event_type, ErrorEventType.INNODB_DEADLOCK)
        self.assertEqual(events[0].error_code, "MY-011925")

    def test_parse_oom_and_table_cache(self):
        log_sample = """
2026-08-21 12:00:00 [ERROR] Out of memory (Needed 1073741824 bytes)
2026-08-21 12:05:00 [ERROR] Can't open file: 'orders.ibd' (errno: 24 - Too many open files)
"""
        events = ErrorLogParser.parse_log_excerpt(log_sample)
        self.assertEqual(len(events), 2)
        self.assertEqual(events[0].event_type, ErrorEventType.MEMORY_OOM)
        self.assertEqual(events[1].event_type, ErrorEventType.TABLE_CACHE_SATURATION)


if __name__ == "__main__":
    unittest.main()
