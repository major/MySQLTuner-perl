"""
Perl Warning, Runtime Exception and Stack Trace Analyzer
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass
from typing import List, Optional, Dict, Any


@dataclass
class StackTraceFinding:
    trace_type: str  # 'PERL_UNINITIALIZED', 'PERL_FATAL', 'SEGFAULT', 'C_ASSERT'
    file_name: str
    line_number: Optional[int]
    subroutine_name: Optional[str]
    raw_message: str
    surrounding_code: Optional[str] = None


class StackTraceAnalyzer:
    PERL_UNINIT_REGEX = re.compile(r"Use of uninitialized value (?:(?:\$|@|%)([a-zA-Z0-9_]+)\s+in\s+)?([^\n\r]+?)\s+at\s+([^\s\n\r]+(?:mysqltuner\.pl|[a-zA-Z0-9_.-]+\.p[lm]))\s+line\s+([0-9]+)", re.IGNORECASE)
    PERL_FATAL_REGEX = re.compile(r"(?:Can't locate [^\n\r]+|Undefined subroutine [^\n\r]+|Can't call method [^\n\r]+|Died at)\s+([^\s\n\r]+(?:mysqltuner\.pl|[a-zA-Z0-9_.-]+\.p[lm]))\s+line\s+([0-9]+)", re.IGNORECASE)
    SEGFAULT_REGEX = re.compile(r"(?:Segmentation fault|SIGSEGV|core dumped|Assertion `.*' failed)", re.IGNORECASE)

    def __init__(self, mysqltuner_path: Optional[str] = None):
        self.mysqltuner_path = mysqltuner_path or os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "..", "mysqltuner.pl")
        )
        self.source_lines: List[str] = []
        self._load_source()

    def _load_source(self):
        if os.path.exists(self.mysqltuner_path):
            try:
                with open(self.mysqltuner_path, "r", encoding="utf-8", errors="ignore") as f:
                    self.source_lines = f.readlines()
            except Exception:
                pass

    def get_subroutine_for_line(self, line_num: int) -> Optional[str]:
        if not self.source_lines or line_num <= 0 or line_num > len(self.source_lines):
            return None

        # Search upwards for 'sub <name>'
        for idx in range(line_num - 1, -1, -1):
            line = self.source_lines[idx]
            m = re.search(r"^\s*sub\s+([a-zA-Z0-9_]+)", line)
            if m:
                return m.group(1)
        return "main"

    def get_surrounding_code(self, line_num: int, context: int = 3) -> Optional[str]:
        if not self.source_lines or line_num <= 0 or line_num > len(self.source_lines):
            return None

        start = max(0, line_num - 1 - context)
        end = min(len(self.source_lines), line_num + context)
        return "".join(self.source_lines[start:end])

    def analyze_text(self, text: str) -> List[StackTraceFinding]:
        findings: List[StackTraceFinding] = []
        if not text:
            return findings

        # Check Perl uninitialized warnings
        for m in self.PERL_UNINIT_REGEX.finditer(text):
            var_name = m.group(1) or ""
            op_desc = m.group(2)
            file_name = os.path.basename(m.group(3))
            line_num = int(m.group(4))
            sub_name = self.get_subroutine_for_line(line_num) if "mysqltuner" in file_name else None
            surrounding = self.get_surrounding_code(line_num) if "mysqltuner" in file_name else None

            findings.append(
                StackTraceFinding(
                    trace_type="PERL_UNINITIALIZED",
                    file_name=file_name,
                    line_number=line_num,
                    subroutine_name=sub_name,
                    raw_message=m.group(0),
                    surrounding_code=surrounding,
                )
            )

        # Check Perl Fatal errors
        for m in self.PERL_FATAL_REGEX.finditer(text):
            file_name = os.path.basename(m.group(1))
            line_num = int(m.group(2))
            sub_name = self.get_subroutine_for_line(line_num) if "mysqltuner" in file_name else None
            surrounding = self.get_surrounding_code(line_num) if "mysqltuner" in file_name else None

            findings.append(
                StackTraceFinding(
                    trace_type="PERL_FATAL",
                    file_name=file_name,
                    line_number=line_num,
                    subroutine_name=sub_name,
                    raw_message=m.group(0),
                    surrounding_code=surrounding,
                )
            )

        # Check Segfaults
        if self.SEGFAULT_REGEX.search(text):
            findings.append(
                StackTraceFinding(
                    trace_type="SEGFAULT",
                    file_name="unknown",
                    line_number=None,
                    subroutine_name=None,
                    raw_message="Segmentation fault or core dump detected in output.",
                )
            )

        return findings
