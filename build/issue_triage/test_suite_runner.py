"""
Test Suite Runner & TAP Output Assertion Coverage Auditor
"""

from __future__ import annotations

import os
import re
import subprocess
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Any


@dataclass
class SingleTestResult:
    file_path: str
    passed: bool
    total_assertions: int
    passed_assertions: int
    failed_assertions: int
    subtest_count: int
    execution_time_seconds: float
    stderr_output: str


@dataclass
class SuiteSummary:
    total_tests_run: int
    passed_tests: int
    failed_tests: int
    total_assertions: int
    success_rate: float
    results: List[SingleTestResult] = field(default_factory=list)


class TestSuiteRunner:
    OK_REGEX = re.compile(r"^\s*ok\s+([0-9]+)", re.MULTILINE)
    NOT_OK_REGEX = re.compile(r"^\s*not\s+ok\s+([0-9]+)", re.MULTILINE)
    SUBTEST_REGEX = re.compile(r"#\s*Subtest:", re.MULTILINE)

    def __init__(self, tests_dir: Optional[str] = None):
        self.tests_dir = tests_dir or os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "..", "tests")
        )

    def run_single_test(self, test_path: str, timeout: int = 15) -> SingleTestResult:
        import time

        t0 = time.time()
        proc = subprocess.run(
            ["perl", "-I.", "-Itests", test_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
        )
        duration = time.time() - t0

        stdout = proc.stdout
        stderr = proc.stderr

        oks = len(self.OK_REGEX.findall(stdout))
        not_oks = len(self.NOT_OK_REGEX.findall(stdout))
        subtests = len(self.SUBTEST_REGEX.findall(stdout))
        passed = (proc.returncode == 0 and not_oks == 0 and oks > 0)

        return SingleTestResult(
            file_path=test_path,
            passed=passed,
            total_assertions=oks + not_oks,
            passed_assertions=oks,
            failed_assertions=not_oks,
            subtest_count=subtests,
            execution_time_seconds=round(duration, 3),
            stderr_output=stderr.strip(),
        )

    def run_suite(self, file_pattern: str = r"^(?:unit_issue_|test_issue_|unit_edge_case_).*") -> SuiteSummary:
        pattern = re.compile(file_pattern)
        test_files = []

        if os.path.exists(self.tests_dir):
            for f in sorted(os.listdir(self.tests_dir)):
                if (f.endswith(".t") or f.endswith(".py")) and pattern.search(f):
                    test_files.append(os.path.join(self.tests_dir, f))

        results: List[SingleTestResult] = []
        for tf in test_files:
            if tf.endswith(".t"):
                res = self.run_single_test(tf)
                results.append(res)

        total_runs = len(results)
        passed_count = sum(1 for r in results if r.passed)
        failed_count = total_runs - passed_count
        total_assertions = sum(r.total_assertions for r in results)
        rate = (passed_count / total_runs * 100.0) if total_runs > 0 else 100.0

        return SuiteSummary(
            total_tests_run=total_runs,
            passed_tests=passed_count,
            failed_tests=failed_count,
            total_assertions=total_assertions,
            success_rate=rate,
            results=results,
        )
