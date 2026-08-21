"""
Unit tests for build.issue_triage.stack_trace_analyzer
"""

import unittest
from build.issue_triage.stack_trace_analyzer import StackTraceAnalyzer


class TestStackTraceAnalyzer(unittest.TestCase):
    def setUp(self):
        self.analyzer = StackTraceAnalyzer()

    def test_parse_perl_uninitialized_warning(self):
        log_sample = "Use of uninitialized value $opt_forcemem in numeric gt (>) at mysqltuner.pl line 150."
        findings = self.analyzer.analyze_text(log_sample)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].trace_type, "PERL_UNINITIALIZED")
        self.assertEqual(findings[0].file_name, "mysqltuner.pl")
        self.assertEqual(findings[0].line_number, 150)
        self.assertIsNotNone(findings[0].subroutine_name)

    def test_parse_perl_fatal_error(self):
        log_sample = "Can't locate object method 'execute' via package 'DBI' at mysqltuner.pl line 300."
        findings = self.analyzer.analyze_text(log_sample)
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].trace_type, "PERL_FATAL")
        self.assertEqual(findings[0].line_number, 300)


if __name__ == "__main__":
    unittest.main()
