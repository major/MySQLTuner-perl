"""
Duplicate Issue Detector and Anomaly Fingerprinter
"""

from __future__ import annotations

import re
import math
from typing import List, Dict, Set, Tuple, Optional, Any
from collections import Counter


class DuplicateIssueDetector:
    TOKEN_REGEX = re.compile(r"[a-zA-Z0-9_]{3,}")

    @classmethod
    def compute_fingerprint(
        cls,
        db_engine: str,
        db_version: str,
        variable_names: List[str],
        error_codes: List[str],
        perl_line_num: Optional[int] = None,
    ) -> str:
        parts = [
            f"db:{db_engine.lower()}",
            f"ver:{db_version.lower() if db_version else 'unknown'}",
            f"vars:{','.join(sorted(set(v.lower() for v in variable_names)))}",
            f"errs:{','.join(sorted(set(e.lower() for e in error_codes)))}",
            f"line:{perl_line_num if perl_line_num is not None else 'none'}",
        ]
        return "|".join(parts)

    @classmethod
    def tokenize(cls, text: str) -> List[str]:
        if not text:
            return []
        return [t.lower() for t in cls.TOKEN_REGEX.findall(text)]

    @classmethod
    def jaccard_similarity(cls, text_a: str, text_b: str) -> float:
        set_a = set(cls.tokenize(text_a))
        set_b = set(cls.tokenize(text_b))
        if not set_a or not set_b:
            return 0.0
        intersection = len(set_a.intersection(set_b))
        union = len(set_a.union(set_b))
        return intersection / union if union > 0 else 0.0

    @classmethod
    def cosine_similarity(cls, text_a: str, text_b: str) -> float:
        tokens_a = cls.tokenize(text_a)
        tokens_b = cls.tokenize(text_b)
        if not tokens_a or not tokens_b:
            return 0.0

        vec_a = Counter(tokens_a)
        vec_b = Counter(tokens_b)

        intersection = set(vec_a.keys()) & set(vec_b.keys())
        numerator = sum(vec_a[x] * vec_b[x] for x in intersection)

        sum_a = sum(v ** 2 for v in vec_a.values())
        sum_b = sum(v ** 2 for v in vec_b.values())
        denominator = math.sqrt(sum_a) * math.sqrt(sum_b)

        return numerator / denominator if denominator > 0 else 0.0

    @classmethod
    def find_duplicates(
        cls,
        target_title: str,
        target_body: str,
        existing_issues: List[Dict[str, Any]],
        threshold: float = 0.65,
    ) -> List[Tuple[int, float]]:
        target_text = f"{target_title} {target_body}"
        matches: List[Tuple[int, float]] = []

        for issue in existing_issues:
            num = issue.get("number", 0)
            other_text = f"{issue.get('title', '')} {issue.get('body', '')}"
            sim = cls.cosine_similarity(target_text, other_text)
            if sim >= threshold:
                matches.append((num, round(sim, 3)))

        return sorted(matches, key=lambda x: x[1], reverse=True)
