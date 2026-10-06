"""
Schema validator for MySQLTuner issue triage records
"""

from __future__ import annotations

import json
import os
import re
from typing import Dict, Any, Tuple, List, Optional


class SchemaValidationError(Exception):
    def __init__(self, errors: List[str]):
        super().__init__(f"Schema validation failed with {len(errors)} errors: {', '.join(errors)}")
        self.errors = errors


class IssueSchemaValidator:
    SCHEMA_PATH = os.path.join(os.path.dirname(__file__), "schemas", "issue_schema.json")

    def __init__(self, custom_schema_path: Optional[str] = None):
        schema_file = custom_schema_path or self.SCHEMA_PATH
        with open(schema_file, "r", encoding="utf-8") as f:
            self.schema = json.load(f)

    def validate_dict(self, record_dict: Dict[str, Any]) -> Tuple[bool, List[str]]:
        errors: List[str] = []

        # Validate required fields
        required_fields = self.schema.get("required", [])
        for req in required_fields:
            if req not in record_dict or record_dict[req] is None:
                errors.append(f"Missing required field: '{req}'")

        # Validate number
        if "number" in record_dict and record_dict["number"] is not None:
            if not isinstance(record_dict["number"], int) or record_dict["number"] < 1:
                errors.append("Field 'number' must be a positive integer >= 1")

        # Validate author_type enum
        valid_author_types = self.schema["properties"]["author_type"]["enum"]
        if "author_type" in record_dict and record_dict["author_type"] is not None:
            if record_dict["author_type"] not in valid_author_types:
                errors.append(f"Invalid 'author_type': {record_dict['author_type']}. Must be one of {valid_author_types}")

        # Validate state enum
        valid_states = self.schema["properties"]["state"]["enum"]
        if "state" in record_dict and record_dict["state"] is not None:
            if record_dict["state"] not in valid_states:
                errors.append(f"Invalid 'state': {record_dict['state']}. Must be one of {valid_states}")

        # Validate category enum
        if "category" in record_dict and record_dict["category"] is not None:
            valid_categories = self.schema["properties"]["category"]["enum"]
            if record_dict["category"] not in valid_categories:
                errors.append(f"Invalid 'category': {record_dict['category']}. Must be one of {valid_categories}")

        # Validate triage_status enum
        if "triage_status" in record_dict and record_dict["triage_status"] is not None:
            valid_statuses = self.schema["properties"]["triage_status"]["enum"]
            if record_dict["triage_status"] not in valid_statuses:
                errors.append(f"Invalid 'triage_status': {record_dict['triage_status']}. Must be one of {valid_statuses}")

        # Validate findings
        if "findings" in record_dict and isinstance(record_dict["findings"], list):
            for idx, finding in enumerate(record_dict["findings"]):
                if not isinstance(finding, dict):
                    errors.append(f"Finding at index {idx} must be a dict")
                    continue
                req_finding = ["rule_id", "title", "severity", "root_cause", "confidence_score", "official_doc_url", "recommendation"]
                for rf in req_finding:
                    if rf not in finding:
                        errors.append(f"Finding[{idx}] missing '{rf}'")
                if "severity" in finding and finding["severity"] not in ["OK", "INFO", "WARN", "BAD", "CRITICAL"]:
                    errors.append(f"Finding[{idx}] invalid severity '{finding['severity']}'")
                if "confidence_score" in finding:
                    score = finding["confidence_score"]
                    if not isinstance(score, (int, float)) or score < 0.0 or score > 1.0:
                        errors.append(f"Finding[{idx}] confidence_score must be between 0.0 and 1.0")

        # Validate test_proofs
        if "test_proofs" in record_dict and isinstance(record_dict["test_proofs"], list):
            for idx, proof in enumerate(record_dict["test_proofs"]):
                if not isinstance(proof, dict):
                    errors.append(f"Test proof at index {idx} must be a dict")
                    continue
                req_proof = ["test_file_path", "test_name", "subtest_count", "syntax_valid", "execution_passed", "output_log_excerpt", "reproduce_command"]
                for rp in req_proof:
                    if rp not in proof:
                        errors.append(f"TestProof[{idx}] missing '{rp}'")
                if "subtest_count" in proof and (not isinstance(proof["subtest_count"], int) or proof["subtest_count"] < 1):
                    errors.append(f"TestProof[{idx}] subtest_count must be integer >= 1")

        is_valid = len(errors) == 0
        return is_valid, errors

    def validate_or_raise(self, record_dict: Dict[str, Any]) -> None:
        is_valid, errors = self.validate_dict(record_dict)
        if not is_valid:
            raise SchemaValidationError(errors)
