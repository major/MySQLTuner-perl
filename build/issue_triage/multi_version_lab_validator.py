"""
Multi-Version Matrix Lab & Interoperability Validator
"""

from __future__ import annotations

import unittest
from typing import List, Dict, Any, Tuple
from build.issue_triage.models import GitHubIssueRecord, IssueAuthorType, DatabaseEngineType
from build.issue_triage.diagnostic_engine import DiagnosticEngine
from build.issue_triage.test_generator import PerlTestGenerator


class MultiVersionLabValidator:
    SUPPORTED_MATRIX = [
        {"engine": "MySQL", "raw": "5.7.44-log", "expected_ver": "5.7.44", "expected_type": DatabaseEngineType.MYSQL},
        {"engine": "MySQL", "raw": "8.0.36-commercial", "expected_ver": "8.0.36", "expected_type": DatabaseEngineType.MYSQL},
        {"engine": "MySQL", "raw": "8.4.0-LTS", "expected_ver": "8.4.0", "expected_type": DatabaseEngineType.MYSQL},
        {"engine": "MySQL", "raw": "9.0.1-innovation", "expected_ver": "9.0.1", "expected_type": DatabaseEngineType.MYSQL},
        {"engine": "MariaDB", "raw": "10.5.23-MariaDB-1:10.5.23+maria~ubu2004", "expected_ver": "10.5.23", "expected_type": DatabaseEngineType.MARIADB},
        {"engine": "MariaDB", "raw": "10.11.8-MariaDB", "expected_ver": "10.11.8", "expected_type": DatabaseEngineType.MARIADB},
        {"engine": "MariaDB", "raw": "11.4.2-MariaDB-deb12", "expected_ver": "11.4.2", "expected_type": DatabaseEngineType.MARIADB},
        {"engine": "Percona", "raw": "8.0.35-27 Percona Server (GPL)", "expected_ver": "8.0.35", "expected_type": DatabaseEngineType.PERCONA},
    ]

    @classmethod
    def validate_matrix(cls) -> Dict[str, Any]:
        engine = DiagnosticEngine()
        test_gen = PerlTestGenerator()
        results = []

        for item in cls.SUPPORTED_MATRIX:
            issue = GitHubIssueRecord(
                number=9000 + len(results),
                title=f"Verification on {item['engine']} {item['raw']}",
                author="matrix_runner",
                author_type=IssueAuthorType.COMMUNITY_USER,
                created_at="2026-08-22T00:00:00Z",
                updated_at="2026-08-22T00:00:00Z",
                state="open",
                body=f"Running on {item['raw']} with 16G RAM\ninnodb_buffer_pool_size = 8G\ntable_open_cache = 2000",
            )
            analyzed = engine.analyze_issue(issue)
            proof = test_gen.write_and_verify_test(analyzed)

            type_match = (analyzed.extracted_metrics.db_engine == item["expected_type"])
            ver_match = (analyzed.extracted_metrics.db_version_normalized == item["expected_ver"])
            proof_ok = proof.syntax_valid and proof.execution_passed

            passed = (type_match and ver_match and proof_ok)
            results.append({
                "matrix_item": item,
                "passed": passed,
                "extracted_engine": analyzed.extracted_metrics.db_engine.value,
                "extracted_version": analyzed.extracted_metrics.db_version_normalized,
                "proof_passed": proof.execution_passed,
            })

        all_passed = all(r["passed"] for r in results)
        return {
            "all_matrix_passed": all_passed,
            "total_tested": len(results),
            "results": results,
        }
