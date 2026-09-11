"""
Text sanitizer and credential redactor for issue parsing
"""

from __future__ import annotations

import re
from typing import Tuple, List


class TextSanitizer:
    # ANSI escape sequence pattern
    ANSI_REGEX = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")

    # HTML comments pattern
    HTML_COMMENT_REGEX = re.compile(r"<!--[\s\S]*?-->")

    # Potentially malicious HTML tags
    DANGEROUS_HTML_REGEX = re.compile(r"<\s*(script|iframe|object|embed|style|meta|link)[^>]*>[\s\S]*?<\s*/\s*\1\s*>", re.IGNORECASE)

    # Secret and credential patterns
    SECRET_PATTERNS = [
        # GitHub tokens
        (re.compile(r"(ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9_]{82})"), "[REDACTED_GITHUB_TOKEN]"),
        # AWS Access Key ID
        (re.compile(r"\b(AKIA[0-9A-Z]{16})\b"), "[REDACTED_AWS_KEY_ID]"),
        # AWS Secret Access Key
        (re.compile(r"(?i)(aws_secret_access_key|aws_session_token)\s*=\s*['\"]?([a-zA-Z0-9/+=]{40})['\"]?"), r"\1=[REDACTED_AWS_SECRET]"),
        # MySQL Connection Strings: mysql://user:password@host:port/db
        (re.compile(r"(mysql(?:x)?://[a-zA-Z0-9_.-]+:)(.+?)(@[a-zA-Z0-9_.-]+:\d+|@[a-zA-Z0-9_.-]+/)"), r"\1[REDACTED_PASSWORD]\3"),
        # MySQL CLI passwords: -pMyPassword or --password=MyPassword
        (re.compile(r"(^|\s)(-p(?!erl\b)|--password=)([\"']?[^\s\"']+)"), r"\1\2[REDACTED_PASSWORD]"),
        # Password in configuration files: password = secret
        (re.compile(r"(?i)(password|passwd|pwd|secret|api_key|token|auth_token)\s*=\s*['\"]?([^ \n\r\t\"']+)['\"]?"), r"\1 = [REDACTED_CREDENTIAL]"),
        # RSA / SSH Private keys
        (re.compile(r"-----BEGIN\s+([A-Z\s]+)?PRIVATE\s+KEY-----[\s\S]*?-----END\s+([A-Z\s]+)?PRIVATE\s+KEY-----"), "[REDACTED_PRIVATE_KEY]"),
        # Bearer tokens
        (re.compile(r"(?i)bearer\s+([a-zA-Z0-9\-._~+/]+=*)"), "Bearer [REDACTED_BEARER_TOKEN]"),
    ]

    @classmethod
    def strip_ansi(cls, text: str) -> str:
        if not text:
            return ""
        return cls.ANSI_REGEX.sub("", text)

    @classmethod
    def strip_dangerous_html(cls, text: str) -> str:
        if not text:
            return ""
        text = cls.HTML_COMMENT_REGEX.sub("", text)
        text = cls.DANGEROUS_HTML_REGEX.sub("", text)
        return text

    @classmethod
    def redact_secrets(cls, text: str) -> Tuple[str, int]:
        if not text:
            return "", 0
        
        redacted_count = 0
        clean_text = text
        for pattern, replacement in cls.SECRET_PATTERNS:
            matches = pattern.findall(clean_text)
            if matches:
                redacted_count += len(matches)
                clean_text = pattern.sub(replacement, clean_text)
        return clean_text, redacted_count

    @classmethod
    def normalize_text(cls, text: str) -> str:
        if not text:
            return ""
        # 1. Strip ANSI
        text = cls.strip_ansi(text)
        # 2. Normalize carriage returns
        text = text.replace("\r\n", "\n").replace("\r", "\n")
        # 3. Strip dangerous HTML
        text = cls.strip_dangerous_html(text)
        # 4. Redact secrets
        text, _ = cls.redact_secrets(text)
        # 5. Remove null bytes or control characters except tabs/newlines
        text = re.sub(r"[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]", "", text)
        return text.strip()
