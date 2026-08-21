"""
Deep Parser for MySQLTuner CLI output and logs
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any
from build.issue_triage.db_taxonomy import DatabaseTaxonomyResolver, ParsedDatabaseInfo


@dataclass
class ParsedIndicator:
    level: str  # 'OK', 'BAD', 'INFO', 'WARN', 'STAT'
    raw_level: str  # '[OK]', '[!!]', '[--]', '[>>]', '[**]'
    message: str


@dataclass
class ParsedMySQLTunerReport:
    mysqltuner_version: Optional[str] = None
    db_info: Optional[ParsedDatabaseInfo] = None
    uptime_seconds: Optional[int] = None
    physical_ram_raw: Optional[str] = None
    max_mysql_ram_raw: Optional[str] = None
    ram_pct_of_system: Optional[float] = None
    indicators: List[ParsedIndicator] = field(default_factory=list)
    general_recommendations: List[str] = field(default_factory=list)
    adjust_variables: Dict[str, str] = field(default_factory=dict)


class MySQLTunerOutputParser:
    BANNER_REGEX = re.compile(r">> MySQLTuner\s+([0-9.]+)", re.IGNORECASE)
    STORAGE_ENGINE_REGEX = re.compile(r"\[--\] Storage Engine Statistics")
    PERF_METRICS_REGEX = re.compile(r"\[--\] Performance Metrics")
    ADJUST_VARS_REGEX = re.compile(r"\[--\] Variables to adjust")
    
    LEVEL_MAP = {
        "[OK]": "OK",
        "[!!]": "BAD",
        "[--]": "INFO",
        "[>>]": "HEADER",
        "[**]": "WARN",
    }

    @classmethod
    def parse_report_text(cls, text: str) -> ParsedMySQLTunerReport:
        report = ParsedMySQLTunerReport()
        if not text:
            return report

        # Extract banner version
        m_banner = cls.BANNER_REGEX.search(text)
        if m_banner:
            report.mysqltuner_version = m_banner.group(1)

        # Extract Version string
        m_ver = re.search(r"Currently running supported MySQL version\s+([^\n\r]+)", text, re.IGNORECASE)
        if not m_ver:
            m_ver = re.search(r"Currently running\s+([0-9.]+[^ \n\r]+)", text, re.IGNORECASE)
        if m_ver:
            report.db_info = DatabaseTaxonomyResolver.resolve(m_ver.group(1).strip(), context_text=text)

        # Extract RAM metrics
        m_ram = re.search(r"Physical RAM\s*:\s*([0-9.]+\s*[KMGT]?i?B?)", text, re.IGNORECASE)
        if m_ram:
            report.physical_ram_raw = m_ram.group(1).strip()

        m_max_ram = re.search(r"Max MySQL memory\s*:\s*([0-9.]+\s*[KMGT]?i?B?)", text, re.IGNORECASE)
        if m_max_ram:
            report.max_mysql_ram_raw = m_max_ram.group(1).strip()

        m_ram_pct = re.search(r"Percentage of RAM\s*:\s*([0-9.]+)\s*%", text, re.IGNORECASE)
        if m_ram_pct:
            try:
                report.ram_pct_of_system = float(m_ram_pct.group(1))
            except ValueError:
                pass

        # Parse indicator lines
        in_adjust_vars = False
        in_general_rec = False

        for line in text.splitlines():
            line_str = line.strip()
            if not line_str:
                continue

            if "Variables to adjust" in line_str:
                in_adjust_vars = True
                in_general_rec = False
                continue
            elif "General recommendations" in line_str:
                in_general_rec = True
                in_adjust_vars = False
                continue

            # Check indicators
            for raw_lvl, norm_lvl in cls.LEVEL_MAP.items():
                if line_str.startswith(raw_lvl):
                    msg = line_str[len(raw_lvl):].strip()
                    report.indicators.append(
                        ParsedIndicator(level=norm_lvl, raw_level=raw_lvl, message=msg)
                    )
                    break

            if in_adjust_vars:
                # e.g.: innodb_buffer_pool_size (>= 16G) or table_open_cache (> 4000)
                m_adj = re.search(r"^([a-zA-Z0-9_]+)\s*(?:\(([^)]+)\)|[=:]\s*([^\s]+))", line_str)
                if m_adj:
                    var_name = m_adj.group(1)
                    val_spec = m_adj.group(2) or m_adj.group(3) or ""
                    report.adjust_variables[var_name] = val_spec.strip()

            elif in_general_rec:
                if line_str.startswith("*") or line_str.startswith("-"):
                    report.general_recommendations.append(line_str.lstrip("*- ").strip())

        return report
