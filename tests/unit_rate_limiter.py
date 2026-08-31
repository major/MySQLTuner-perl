"""
Unit tests for build.issue_triage.rate_limiter
"""

import unittest
from build.issue_triage.rate_limiter import AdaptiveRateLimiter
from build.issue_triage.github_rest_client import GitHubAPIError


class TestAdaptiveRateLimiter(unittest.TestCase):
    def setUp(self):
        self.limiter = AdaptiveRateLimiter(min_safety_margin=2, base_backoff=0.01, max_backoff=0.1, max_retries=3)

    def test_compute_backoff_with_retry_after(self):
        bo = self.limiter.compute_backoff(0, retry_after=5)
        self.assertGreaterEqual(bo, 5.0)
        self.assertLessEqual(bo, 6.0)

    def test_compute_backoff_jitter(self):
        bo = self.limiter.compute_backoff(1)
        self.assertGreaterEqual(bo, 0.0)
        self.assertLessEqual(bo, 0.1)

    def test_retry_on_429_success(self):
        sleeps = []
        attempts = 0

        def flaky_func():
            nonlocal attempts
            attempts += 1
            if attempts < 3:
                raise GitHubAPIError(429, "Rate limit exceeded")
            return "SUCCESS"

        result = self.limiter.execute_with_retry(flaky_func, sleeper=lambda s: sleeps.append(s))
        self.assertEqual(result, "SUCCESS")
        self.assertEqual(attempts, 3)
        self.assertEqual(len(sleeps), 2)

    def test_fail_after_max_retries(self):
        def always_fail():
            raise GitHubAPIError(500, "Internal Server Error")

        with self.assertRaises(GitHubAPIError):
            self.limiter.execute_with_retry(always_fail, sleeper=lambda s: None)


if __name__ == "__main__":
    unittest.main()
