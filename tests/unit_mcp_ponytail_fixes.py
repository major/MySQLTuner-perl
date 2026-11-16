"""
TDD unit tests for Ponytail Finding #10 fixes in build.mcp_server.
"""

import atexit
import json
import os
import shutil
import subprocess
import tempfile
import threading
import unittest
from unittest import mock

_TEST_CACHE_DIR = tempfile.mkdtemp(prefix="mcp_ponytail_test_")
atexit.register(lambda: shutil.rmtree(_TEST_CACHE_DIR, ignore_errors=True))
os.environ["CACHE_DIR"] = _TEST_CACHE_DIR

import build.mcp_server as mcp_server  # noqa: E402


class TestMCPAnalyzeBufferPool(unittest.TestCase):
    def test_db_failure_returns_is_error_instead_of_fabricated_metrics(self):
        with mock.patch.object(
            mcp_server,
            "run_db_query",
            return_value=(False, "ERROR 2002 (HY000): Can't connect to local MySQL server"),
        ):
            res = mcp_server.handle_analyze_buffer_pool({})

        self.assertTrue(res.get("isError"), "Expected isError=True when DB query fails")
        text = res["content"][0]["text"]
        self.assertIn("Can't connect", text)
        self.assertNotIn("OPTIMAL", text)
        self.assertNotIn("99.95", text)

    def test_partial_db_failure_on_variables_query_returns_is_error(self):
        responses = [
            (True, "Innodb_buffer_pool_read_requests\t1000\nInnodb_buffer_pool_reads\t1\nInnodb_buffer_pool_pages_total\t1024\nInnodb_buffer_pool_pages_data\t512\nInnodb_buffer_pool_pages_free\t512\nInnodb_buffer_pool_pages_dirty\t10\nInnodb_page_size\t16384\n"),
            (False, "ERROR 1227 (42000): Access denied"),
        ]
        with mock.patch.object(mcp_server, "run_db_query", side_effect=responses):
            res = mcp_server.handle_analyze_buffer_pool({})

        self.assertTrue(res.get("isError"))
        self.assertIn("Access denied", res["content"][0]["text"])

    def test_honors_target_ram_percentage_and_default(self):
        status_out = (
            "Innodb_buffer_pool_read_requests\t100000\n"
            "Innodb_buffer_pool_reads\t100\n"
            "Innodb_buffer_pool_pages_total\t49152\n"
            "Innodb_buffer_pool_pages_data\t40000\n"
            "Innodb_buffer_pool_pages_free\t9152\n"
            "Innodb_buffer_pool_pages_dirty\t200\n"
            "Innodb_page_size\t16384\n"
        )
        # 768 MB allocated out of mocked 1024 MB host RAM
        vars_out = (
            "innodb_buffer_pool_size\t805306368\n"
            "innodb_buffer_pool_instances\t1\n"
        )
        data_out = "268435456"
        host_ram = 1024 * 1024 * 1024  # 1024 MB

        with mock.patch.dict(os.environ, {"DB_HOST": "127.0.0.1"}):
            with mock.patch.object(mcp_server, "_get_available_ram_bytes", return_value=host_ram):
                with mock.patch.object(
                    mcp_server,
                    "run_db_query",
                    side_effect=[(True, status_out), (True, vars_out), (True, data_out)],
                ):
                    res_50 = mcp_server.handle_analyze_buffer_pool({"target_ram_percentage": 50})
                    self.assertFalse(res_50.get("isError", False))
                    payload_50 = json.loads(res_50["content"][0]["text"])
                    self.assertEqual(payload_50["metrics"]["target_ram_percentage"], 50.0)
                    self.assertEqual(payload_50["status"], "OVERSIZED")
                    self.assertTrue(
                        any("536870912" in rec["action"] for rec in payload_50["recommendations"]),
                        f"Expected 50% target (536870912) recommendation, got {payload_50['recommendations']}",
                    )

                with mock.patch.object(
                    mcp_server,
                    "run_db_query",
                    side_effect=[(True, status_out), (True, vars_out), (True, data_out)],
                ):
                    res_80 = mcp_server.handle_analyze_buffer_pool({"target_ram_percentage": 80})
                    self.assertFalse(res_80.get("isError", False))
                    payload_80 = json.loads(res_80["content"][0]["text"])
                    self.assertEqual(payload_80["metrics"]["target_ram_percentage"], 80.0)
                    self.assertEqual(payload_80["status"], "OPTIMAL")

                with mock.patch.object(
                    mcp_server,
                    "run_db_query",
                    side_effect=[(True, status_out), (True, vars_out), (True, data_out)],
                ):
                    res_default = mcp_server.handle_analyze_buffer_pool({})
                    self.assertFalse(res_default.get("isError", False))
                    payload_default = json.loads(res_default["content"][0]["text"])
                    self.assertEqual(payload_default["metrics"]["target_ram_percentage"], 75.0)
                    self.assertEqual(payload_default["status"], "OPTIMAL")

    def test_invalid_target_ram_percentage_returns_is_error(self):
        for bad_val in (-10, 0, 105, "not-a-number"):
            res = mcp_server.handle_analyze_buffer_pool({"target_ram_percentage": bad_val})
            self.assertTrue(res.get("isError"), f"Expected isError=True for target_ram_percentage={bad_val!r}")


class TestMCPCacheLockAndAtomicWrites(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp(prefix="mcp_cache_atomic_")
        self.addCleanup(shutil.rmtree, self.tmpdir, True)
        self.orig_json = mcp_server.LATEST_JSON
        self.orig_html = mcp_server.LATEST_HTML
        self.orig_script = mcp_server.MYSQLTUNER_SCRIPT
        mcp_server.LATEST_JSON = os.path.join(self.tmpdir, "latest.json")
        mcp_server.LATEST_HTML = os.path.join(self.tmpdir, "latest.html")
        mcp_server.MYSQLTUNER_SCRIPT = os.path.abspath("mysqltuner.pl")

    def tearDown(self):
        mcp_server.LATEST_JSON = self.orig_json
        mcp_server.LATEST_HTML = self.orig_html
        mcp_server.MYSQLTUNER_SCRIPT = self.orig_script

    def test_concurrent_cache_writes_and_reads_are_atomic_and_locked(self):
        self.assertTrue(hasattr(mcp_server, "CACHE_LOCK"))

        counter = {"n": 0}
        counter_lock = threading.Lock()
        errors = []

        def fake_subprocess_run(args, capture_output=True, text=True, check=True):
            idx = args.index("--reportfile")
            report_path = args[idx + 1]
            self.assertNotEqual(
                os.path.abspath(report_path),
                os.path.abspath(mcp_server.LATEST_HTML),
                "run_mysqltuner_cmd must write HTML to a staging temp file before atomic os.replace",
            )
            with counter_lock:
                counter["n"] += 1
                seq = counter["n"]
            with open(report_path, "w", encoding="utf-8") as fh:
                fh.write(f"<html><body>Report {seq}</body></html>")
            payload = json.dumps({"seq": seq, "blob": "x" * 4096})
            return subprocess.CompletedProcess(args=args, returncode=0, stdout=payload, stderr="")

        def writer():
            for _ in range(15):
                ok, _ = mcp_server.run_mysqltuner_cmd()
                if not ok:
                    errors.append("writer returned False")

        def reader():
            for _ in range(30):
                res = mcp_server.handle_get_latest_audit({})
                txt = res["content"][0]["text"]
                if txt.startswith("{"):
                    try:
                        data = json.loads(txt)
                        assert "seq" in data and len(data["blob"]) == 4096
                    except Exception as exc:
                        errors.append(f"corrupt JSON read: {exc}")
                rpc_res, _ = mcp_server.dispatch_jsonrpc({
                    "jsonrpc": "2.0",
                    "method": "resources/read",
                    "params": {"uri": "mysqltuner://reports/latest.html"},
                    "id": 1,
                })
                html_txt = rpc_res["result"]["contents"][0]["text"]
                if html_txt.startswith("<html>") and not html_txt.endswith("</html>"):
                    errors.append(f"truncated HTML read: {html_txt!r}")

        with mock.patch.object(mcp_server.subprocess, "run", side_effect=fake_subprocess_run):
            threads = [threading.Thread(target=writer), threading.Thread(target=writer)]
            threads.extend(threading.Thread(target=reader) for _ in range(3))
            for t in threads:
                t.start()
            for t in threads:
                t.join()

        self.assertEqual(errors, [])
        leftovers = [f for f in os.listdir(self.tmpdir) if f.startswith(".tmp")]
        self.assertEqual(leftovers, [], f"Found leftover temp files: {leftovers}")


class TestMCPSanitizeSQLStatement(unittest.TestCase):
    def test_allows_valid_single_statements_with_optional_trailing_semicolon(self):
        valid_cases = [
            "SET GLOBAL slow_query_log = ON",
            "SET GLOBAL max_connections = 200;",
            "SET @@GLOBAL.innodb_buffer_pool_size = 1073741824;",
            "SET PERSIST innodb_flush_log_at_trx_commit = 2;",
            "OPTIMIZE TABLE `app`.`orders`;",
            "ALTER TABLE `app`.`orders` ENGINE=InnoDB;",
            "ANALYZE TABLE `app`.`orders`;",
        ]
        for stmt in valid_cases:
            ok, reason, cleaned = mcp_server.sanitize_sql_statement(stmt)
            self.assertTrue(ok, f"Expected valid statement {stmt!r} to pass, got: {reason}")
            self.assertNotIn(";", cleaned)

    def test_rejects_embedded_or_double_semicolons_and_unclosed_comments(self):
        bad_cases = [
            "SET GLOBAL max_connections = 100; DROP TABLE users;",
            "SET GLOBAL max_connections = 100;;",
            "; SET GLOBAL max_connections = 100",
            "SET GLOBAL init_connect = 'SELECT 1; SELECT 2'",
            "SET GLOBAL max_connections = 100 /* unclosed",
            ";",
        ]
        for stmt in bad_cases:
            ok, reason, _ = mcp_server.sanitize_sql_statement(stmt)
            self.assertFalse(ok, f"Expected statement {stmt!r} to be rejected")

    def test_rejects_destructive_and_privilege_keywords(self):
        destructive_cases = [
            "DROP DATABASE prod",
            "TRUNCATE TABLE users",
            "DELETE FROM users",
            "SHUTDOWN",
            "GRANT ALL PRIVILEGES ON *.* TO 'a'@'%'",
            "REVOKE ALL PRIVILEGES ON *.* FROM 'a'@'%'",
            "SET GLOBAL log_bin = 1 INTO OUTFILE '/tmp/x'",
            "SET GLOBAL log_bin = 1 INTO/*bypass*/OUTFILE '/tmp/x'",
            "SET GLOBAL init_connect = LOAD_FILE('/etc/passwd')",
            "ALTER TABLE app.users DROP COLUMN secret",
        ]
        for stmt in destructive_cases:
            ok, _, _ = mcp_server.sanitize_sql_statement(stmt)
            self.assertFalse(ok, f"Expected destructive statement {stmt!r} to be rejected")


if __name__ == "__main__":
    unittest.main()
