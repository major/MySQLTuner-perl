"""
Persistent JSON Disk Cache Manager with TTL & Atomic Writes
"""

from __future__ import annotations

import hashlib
import json
import os
import tempfile
import time
from typing import Any, Optional, Dict


class DiskCacheManager:
    DEFAULT_CACHE_DIR = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "..", ".triage_cache")
    )

    def __init__(self, cache_dir: Optional[str] = None, default_ttl_seconds: int = 3600):
        self.cache_dir = cache_dir or self.DEFAULT_CACHE_DIR
        self.default_ttl = default_ttl_seconds
        os.makedirs(self.cache_dir, exist_ok=True)

    def _get_cache_path(self, key: str) -> str:
        key_hash = hashlib.sha256(key.encode("utf-8")).hexdigest()
        return os.path.join(self.cache_dir, f"{key_hash}.json")

    def get(self, key: str) -> Optional[Any]:
        cache_file = self._get_cache_path(key)
        if not os.path.exists(cache_file):
            return None

        try:
            with open(cache_file, "r", encoding="utf-8") as f:
                data = json.load(f)

            expires_at = data.get("_expires_at", 0)
            if time.time() > expires_at:
                try:
                    os.remove(cache_file)
                except OSError:
                    pass
                return None

            return data.get("payload")
        except Exception:
            return None

    def set(self, key: str, value: Any, ttl_seconds: Optional[int] = None) -> None:
        ttl = ttl_seconds if ttl_seconds is not None else self.default_ttl
        cache_file = self._get_cache_path(key)
        expires_at = time.time() + ttl

        data = {
            "_key": key,
            "_expires_at": expires_at,
            "_created_at": time.time(),
            "payload": value,
        }

        tmp_fd, tmp_path = tempfile.mkstemp(dir=self.cache_dir, prefix="tmp_cache_")
        try:
            with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
            os.replace(tmp_path, cache_file)
        except Exception:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def clear(self) -> int:
        count = 0
        if os.path.exists(self.cache_dir):
            for f in os.listdir(self.cache_dir):
                if f.endswith(".json"):
                    try:
                        os.remove(os.path.join(self.cache_dir, f))
                        count += 1
                    except OSError:
                        pass
        return count
