"""
Unit tests for build.issue_triage.disk_cache_manager
"""

import os
import shutil
import tempfile
import time
import unittest
from build.issue_triage.disk_cache_manager import DiskCacheManager


class TestDiskCacheManager(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.cache = DiskCacheManager(cache_dir=self.tmpdir, default_ttl_seconds=2)

    def tearDown(self):
        if os.path.exists(self.tmpdir):
            shutil.rmtree(self.tmpdir)

    def test_cache_hit_and_miss(self):
        self.assertIsNone(self.cache.get("non_existent_key"))

        self.cache.set("issue_100", {"title": "Test Issue", "number": 100})
        cached = self.cache.get("issue_100")
        self.assertIsNotNone(cached)
        self.assertEqual(cached["title"], "Test Issue")

    def test_cache_ttl_expiration(self):
        self.cache.set("short_key", "value", ttl_seconds=1)
        self.assertEqual(self.cache.get("short_key"), "value")
        time.sleep(1.2)
        self.assertIsNone(self.cache.get("short_key"))


if __name__ == "__main__":
    unittest.main()
