"""
Adaptive Rate Limiter with Exponential Jitter Backoff & Retry
"""

from __future__ import annotations

import time
import random
import logging
from typing import Optional, Callable, Any, Dict

logger = logging.getLogger("issue_triage.rate_limiter")


class RateLimitExceeded(Exception):
    pass


class AdaptiveRateLimiter:
    def __init__(
        self,
        min_safety_margin: int = 5,
        base_backoff: float = 1.0,
        max_backoff: float = 60.0,
        max_retries: int = 4,
    ):
        self.min_safety_margin = min_safety_margin
        self.base_backoff = base_backoff
        self.max_backoff = max_backoff
        self.max_retries = max_retries
        self.remaining_calls = 5000
        self.reset_timestamp = 0

    def update_from_headers(self, headers: Dict[str, str]):
        for k, v in headers.items():
            k_lower = k.lower()
            if k_lower == "x-ratelimit-remaining":
                try:
                    self.remaining_calls = int(v)
                except ValueError:
                    pass
            elif k_lower == "x-ratelimit-reset":
                try:
                    self.reset_timestamp = int(v)
                except ValueError:
                    pass

    def compute_backoff(self, attempt: int, retry_after: Optional[int] = None) -> float:
        if retry_after is not None and retry_after > 0:
            return float(retry_after) + random.uniform(0.1, 0.5)

        # Full jitter algorithm
        cap = min(self.max_backoff, self.base_backoff * (2 ** attempt))
        return random.uniform(0, cap)

    def guard_before_call(self):
        # If running out of calls, pause until reset
        if self.remaining_calls <= self.min_safety_margin and self.reset_timestamp > 0:
            now = int(time.time())
            wait_seconds = max(0, self.reset_timestamp - now) + 1
            if wait_seconds > 0 and wait_seconds < 3600:
                logger.warning(f"Approaching rate limit quota ({self.remaining_calls} remaining). Pausing for {wait_seconds}s...")
                time.sleep(wait_seconds)
                self.remaining_calls = 5000  # Reset assumed after cooldown

    def execute_with_retry(self, func: Callable[[], Any], sleeper: Callable[[float], None] = time.sleep) -> Any:
        self.guard_before_call()

        last_exception = None
        for attempt in range(self.max_retries + 1):
            try:
                return func()
            except Exception as exc:
                last_exception = exc
                status_code = getattr(exc, "status_code", 0)
                
                # Check for rate limit or server error codes
                if status_code in [429, 403, 500, 502, 503, 504] and attempt < self.max_retries:
                    retry_after = getattr(exc, "retry_after", None)
                    wait_time = self.compute_backoff(attempt, retry_after)
                    logger.warning(f"Call failed with HTTP {status_code}. Retrying in {wait_time:.2f}s (Attempt {attempt+1}/{self.max_retries})")
                    sleeper(wait_time)
                    continue
                raise

        raise last_exception or RateLimitExceeded("Max retries exceeded")
