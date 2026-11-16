#!/usr/bin/env python3
"""
MySQLTuner MCP (Model Context Protocol) Server
Compliant with MCP 2024-11-05 and JSON-RPC 2.0 Specifications.
Dual transport support: stdio and SSE (Server-Sent Events).
Zero non-standard dependencies (Python 3 standard library only).
"""

import sys
import os
import json
import time
import re
import threading
import subprocess
import tempfile
import traceback
import argparse
import urllib.parse
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import uuid

# Configuration & Defaults
CACHE_DIR = os.environ.get("CACHE_DIR", "/var/cache/mysqltuner")
AUDIT_INTERVAL_HOURS = float(os.environ.get("AUDIT_INTERVAL_HOURS", "12"))
READ_ONLY = os.environ.get("READ_ONLY", "false").lower() in ("true", "1", "yes")
MYSQLTUNER_SCRIPT = os.environ.get("MYSQLTUNER_PL", "mysqltuner.pl")
SERVER_VERSION = "2.9.4"
PROTOCOL_VERSION = "2024-11-05"

# Ensure cache directory exists
os.makedirs(CACHE_DIR, exist_ok=True)

STATE_FILE = os.path.join(CACHE_DIR, "state.json")
LATEST_JSON = os.path.join(CACHE_DIR, "latest.json")
LATEST_HTML = os.path.join(CACHE_DIR, "latest.html")

CACHE_LOCK = threading.Lock()
STATE_LOCK = threading.RLock()


def _atomic_write_text(target_path, content):
    parent = os.path.dirname(os.path.abspath(target_path))
    os.makedirs(parent, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(prefix=".tmp_", dir=parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_path, target_path)
    except Exception:
        if os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
        raise


# State Management
def load_state():
    with STATE_LOCK:
        if os.path.exists(STATE_FILE):
            try:
                with open(STATE_FILE, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return {"applied": []}


def save_state(state):
    with STATE_LOCK:
        try:
            _atomic_write_text(STATE_FILE, json.dumps(state, indent=2))
        except Exception as e:
            sys.stderr.write(f"Failed to save state: {e}\n")


# Execution Helpers
def run_mysqltuner_cmd():
    script_path = MYSQLTUNER_SCRIPT
    if not os.path.isabs(script_path) and not os.path.exists(script_path):
        # Look in workspace or current dir
        cand = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mysqltuner.pl")
        if os.path.exists(cand):
            script_path = os.path.abspath(cand)

    html_dir = os.path.dirname(os.path.abspath(LATEST_HTML))
    os.makedirs(html_dir, exist_ok=True)
    tmp_html_fd, tmp_html_path = tempfile.mkstemp(prefix=".tmp_report_", suffix=".html", dir=html_dir)
    os.close(tmp_html_fd)

    args = ["/usr/bin/perl", script_path, "--prettyjson", "--reportfile", tmp_html_path]

    db_host = os.environ.get("DB_HOST")
    db_port = os.environ.get("DB_PORT")
    db_user = os.environ.get("DB_USER")
    db_pass = os.environ.get("DB_PASSWORD")

    if db_host:
        args.extend(["--host", db_host])
    if db_port:
        args.extend(["--port", db_port])
    if db_user:
        args.extend(["--user", db_user])
    if db_pass:
        args.extend(["--pass", db_pass])

    try:
        result = subprocess.run(args, capture_output=True, text=True, check=True)
        with CACHE_LOCK:
            _atomic_write_text(LATEST_JSON, result.stdout)
            if os.path.exists(tmp_html_path) and os.path.getsize(tmp_html_path) > 0:
                os.replace(tmp_html_path, LATEST_HTML)
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        err_msg = f"MySQLTuner failed with code {e.returncode}: {e.stderr or e.stdout}"
        return False, err_msg
    except Exception as e:
        return False, str(e)
    finally:
        if os.path.exists(tmp_html_path):
            try:
                os.unlink(tmp_html_path)
            except OSError:
                pass

def run_db_query(query):
    mysql_cmd = ["mysql", "-Bse", query]
    db_host = os.environ.get("DB_HOST")
    db_port = os.environ.get("DB_PORT")
    db_user = os.environ.get("DB_USER")
    db_pass = os.environ.get("DB_PASSWORD")

    if db_host:
        mysql_cmd.extend(["-h", db_host])
    if db_port:
        mysql_cmd.extend(["-P", db_port])
    if db_user:
        mysql_cmd.extend(["-u", db_user])
    if db_pass:
        mysql_cmd.extend([f"-p{db_pass}"])

    try:
        res = subprocess.run(mysql_cmd, capture_output=True, text=True, check=True)
        return True, res.stdout.strip()
    except subprocess.CalledProcessError as e:
        return False, e.stderr.strip() if e.stderr else str(e)
    except Exception as e:
        return False, str(e)

# SQL Sanitizer & Safety Guardrails
def sanitize_sql_statement(statement):
    """
    Strips comments and validates statement safety against injection and destructive operations.
    Returns (is_safe: bool, reason: str, cleaned_statement: str)
    """
    if not statement or not isinstance(statement, str):
        return False, "Statement must be a non-empty string.", ""

    # Strip inline comments -- and #
    lines = statement.splitlines()
    stripped_lines = []
    for line in lines:
        line_clean = re.sub(r'(--|#).*$', '', line)
        stripped_lines.append(line_clean)
    stmt = "\n".join(stripped_lines)

    # Strip block comments /* ... */ (replace with space so adjacent tokens cannot merge/evade)
    stmt = re.sub(r'/\*.*?\*/', ' ', stmt, flags=re.DOTALL).strip()
    if "/*" in stmt:
        return False, "Unclosed block comment in SQL statement.", ""

    if not stmt:
        return False, "Statement is empty after comment stripping.", ""

    # Allow at most one trailing semicolon; reject any embedded or repeated semicolons
    stmt_body = stmt[:-1].strip() if stmt.endswith(";") else stmt
    if not stmt_body:
        return False, "Statement is empty after comment stripping.", ""
    if ";" in stmt_body:
        return False, "Multiple SQL statements in a single execution are strictly prohibited for safety.", ""

    single_stmt = stmt_body
    normalized = re.sub(r'\s+', ' ', single_stmt).upper().strip()

    # Disallow destructive keywords anywhere in statement
    blacklisted = [
        r'\bDROP\b', r'\bDELETE\b', r'\bTRUNCATE\b', r'\bINSERT\b', r'\bUPDATE\b',
        r'\bGRANT\b', r'\bREVOKE\b', r'\bCREATE\b', r'\bREPLACE\b', r'\bEXECUTE\b',
        r'\bCALL\b', r'\bLOAD_FILE\b', r'\bLOAD\s+DATA\b', r'\bINTO\s+OUTFILE\b', r'\bINTO\s+DUMPFILE\b',
        r'\bSHUTDOWN\b', r'\bKILL\b', r'\bFLUSH\s+PRIVILEGES\b'
    ]
    for pattern in blacklisted:
        if re.search(pattern, normalized):
            return False, f"Dangerous or destructive SQL operation detected matching pattern '{pattern}'.", ""

    # Allowlist permitted tuning operations
    allowed_prefixes = ("SET GLOBAL ", "SET @@GLOBAL.", "SET PERSIST ", "ALTER TABLE ", "OPTIMIZE TABLE ", "ANALYZE TABLE ")
    if not any(normalized.startswith(prefix) for prefix in allowed_prefixes):
        return False, f"Execution rejected: Statement must begin with one of {allowed_prefixes}.", ""

    return True, "OK", single_stmt

# Tool Handlers
def handle_get_latest_audit(arguments):
    with CACHE_LOCK:
        if os.path.exists(LATEST_JSON):
            try:
                with open(LATEST_JSON, "r", encoding="utf-8") as f:
                    content = f.read()
                return {"content": [{"type": "text", "text": content}]}
            except Exception as e:
                return {"isError": True, "content": [{"type": "text", "text": f"Error reading cached audit: {str(e)}"}]}
    return {"content": [{"type": "text", "text": "No cached audit findings found. Try running run_audit first."}]}

def handle_run_audit(arguments):
    success, output = run_mysqltuner_cmd()
    if success:
        return {"content": [{"type": "text", "text": output}]}
    return {"isError": True, "content": [{"type": "text", "text": f"Failed to execute audit: {output}"}]}

def handle_apply_recommendation(arguments):
    if READ_ONLY:
        return {"isError": True, "content": [{"type": "text", "text": "Execution rejected: MCP server is running in read-only mode."}]}

    if not isinstance(arguments, dict):
        return {"isError": True, "content": [{"type": "text", "text": "Arguments must be a JSON object."}]}

    statement = arguments.get("statement")
    if not statement:
        return {"isError": True, "content": [{"type": "text", "text": "Missing parameter: 'statement' is required."}]}

    is_safe, reason, clean_stmt = sanitize_sql_statement(statement)
    if not is_safe:
        return {"isError": True, "content": [{"type": "text", "text": f"Safety verification failed: {reason}"}]}

    var_name = arguments.get("variable_name")
    old_value = None
    if var_name:
        # Validate variable name characters (alphanumeric and underscore only)
        if re.match(r'^[a-zA-Z0-9_]+$', var_name):
            success, val = run_db_query(f"SELECT @@global.{var_name}")
            if success:
                old_value = val

    success, err = run_db_query(clean_stmt)
    if not success:
        return {"isError": True, "content": [{"type": "text", "text": f"SQL Execution failed: {err}"}]}

    with STATE_LOCK:
        state = load_state()
        stmt_id = str(int(time.time() * 1000))
        state["applied"].append({
            "id": stmt_id,
            "statement": clean_stmt,
            "variable_name": var_name,
            "old_value": old_value,
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        })
        save_state(state)

    return {"content": [{"type": "text", "text": f"Success: Statement executed successfully. Statement ID: {stmt_id}"}]}

def handle_rollback_recommendation(arguments):
    if READ_ONLY:
        return {"isError": True, "content": [{"type": "text", "text": "Execution rejected: MCP server is running in read-only mode."}]}

    if not isinstance(arguments, dict):
        return {"isError": True, "content": [{"type": "text", "text": "Arguments must be a JSON object."}]}

    stmt_id = arguments.get("statement_id")
    if not stmt_id:
        return {"isError": True, "content": [{"type": "text", "text": "Missing parameter: 'statement_id' is required."}]}

    with STATE_LOCK:
        state = load_state()
        target = None
        for entry in state.get("applied", []):
            if entry.get("id") == str(stmt_id):
                target = entry
                break

        if not target:
            return {"isError": True, "content": [{"type": "text", "text": f"Error: Statement ID {stmt_id} not found in state registry."}]}

        var_name = target.get("variable_name")
        old_value = target.get("old_value")

        if var_name and old_value is not None:
            if not re.match(r'^[a-zA-Z0-9_]+$', var_name):
                return {"isError": True, "content": [{"type": "text", "text": f"Invalid variable name in state: {var_name}"}]}
            # Safely quote string or numeric
            if isinstance(old_value, (int, float)) or str(old_value).isdigit():
                rollback_stmt = f"SET GLOBAL {var_name} = {old_value}"
            else:
                escaped_val = str(old_value).replace("'", "''")
                rollback_stmt = f"SET GLOBAL {var_name} = '{escaped_val}'"

            success, err = run_db_query(rollback_stmt)
            if not success:
                return {"isError": True, "content": [{"type": "text", "text": f"Rollback SQL failed: {err}"}]}
        else:
            return {"isError": True, "content": [{"type": "text", "text": "Cannot rollback: This statement type does not have a captured previous state."}]}

        state["applied"].remove(target)
        save_state(state)

    return {"content": [{"type": "text", "text": f"Success: Rollback executed successfully: {rollback_stmt}"}]}

def _get_available_ram_bytes():
    db_host = (os.environ.get("DB_HOST") or "").strip().lower()
    if db_host not in ("", "127.0.0.1", "localhost", "::1"):
        return None

    mem_bytes = None
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    parts = line.split()
                    if len(parts) >= 2 and parts[1].isdigit():
                        mem_bytes = int(parts[1]) * 1024
                    break
    except OSError:
        pass

    if mem_bytes is None and hasattr(os, "sysconf"):
        try:
            mem_bytes = int(os.sysconf("SC_PHYS_PAGES")) * int(os.sysconf("SC_PAGE_SIZE"))
        except (ValueError, OSError):
            pass

    # Cap by container cgroup limit when running inside a memory-constrained container
    for cg_path in ("/sys/fs/cgroup/memory.max", "/sys/fs/cgroup/memory/memory.limit_in_bytes"):
        try:
            with open(cg_path, "r", encoding="utf-8") as f:
                raw = f.read().strip()
            if raw.isdigit():
                cg_val = int(raw)
                if 0 < cg_val < (1 << 60):
                    mem_bytes = cg_val if mem_bytes is None else min(mem_bytes, cg_val)
                    break
        except OSError:
            pass

    return mem_bytes if mem_bytes and mem_bytes > 0 else None

def handle_analyze_buffer_pool(arguments):
    if not isinstance(arguments, dict):
        arguments = {}

    raw_include_dirty = arguments.get("include_dirty_pages", True)
    include_dirty = True if raw_include_dirty is None else bool(raw_include_dirty)

    raw_target_ram = arguments.get("target_ram_percentage")
    if raw_target_ram is None:
        target_ram_pct = 75.0
    elif isinstance(raw_target_ram, bool):
        return {"isError": True, "content": [{"type": "text", "text": f"Invalid target_ram_percentage: {raw_target_ram!r}"}]}
    else:
        try:
            target_ram_pct = float(raw_target_ram)
        except (TypeError, ValueError):
            return {"isError": True, "content": [{"type": "text", "text": f"Invalid target_ram_percentage: {raw_target_ram!r}"}]}
    if not (0.0 < target_ram_pct <= 100.0):
        return {"isError": True, "content": [{"type": "text", "text": "Invalid target_ram_percentage: must be > 0 and <= 100."}]}

    # 1. Query live database status (fail closed on error; never fabricate OPTIMAL fallback metrics)
    query_status = "SHOW GLOBAL STATUS WHERE Variable_name IN ('Innodb_buffer_pool_read_requests', 'Innodb_buffer_pool_reads', 'Innodb_buffer_pool_pages_total', 'Innodb_buffer_pool_pages_data', 'Innodb_buffer_pool_pages_free', 'Innodb_buffer_pool_pages_dirty', 'Innodb_page_size');"
    query_vars = "SHOW GLOBAL VARIABLES WHERE Variable_name IN ('innodb_buffer_pool_size', 'innodb_buffer_pool_instances', 'innodb_buffer_pool_chunk_size');"
    query_data = "SELECT IFNULL(SUM(data_length + index_length), 0) FROM information_schema.TABLES WHERE engine = 'InnoDB';"

    status_dict = {}
    vars_dict = {}
    dataset_bytes = 0

    s_ok, s_out = run_db_query(query_status)
    if not s_ok:
        return {"isError": True, "content": [{"type": "text", "text": f"Failed to query InnoDB buffer pool status: {s_out}"}]}
    if s_out:
        for line in s_out.strip().splitlines():
            p = line.split()
            if len(p) >= 2:
                status_dict[p[0]] = p[1]

    v_ok, v_out = run_db_query(query_vars)
    if not v_ok:
        return {"isError": True, "content": [{"type": "text", "text": f"Failed to query InnoDB buffer pool variables: {v_out}"}]}
    if v_out:
        for line in v_out.strip().splitlines():
            p = line.split()
            if len(p) >= 2:
                vars_dict[p[0]] = p[1]

    d_ok, d_out = run_db_query(query_data)
    if not d_ok:
        return {"isError": True, "content": [{"type": "text", "text": f"Failed to query InnoDB dataset size: {d_out}"}]}
    if d_out and d_out.strip().isdigit():
        dataset_bytes = int(d_out.strip())

    # Parsed metrics (zero-safe defaults only for omitted optional keys)
    read_req = int(status_dict.get("Innodb_buffer_pool_read_requests", 0))
    reads = int(status_dict.get("Innodb_buffer_pool_reads", 0))
    pages_total = int(status_dict.get("Innodb_buffer_pool_pages_total", 0))
    pages_free = int(status_dict.get("Innodb_buffer_pool_pages_free", 0))
    pages_dirty = int(status_dict.get("Innodb_buffer_pool_pages_dirty", 0))
    page_size = int(status_dict.get("Innodb_page_size", 16384))
    bp_size = int(vars_dict.get("innodb_buffer_pool_size", pages_total * page_size))
    instances = int(vars_dict.get("innodb_buffer_pool_instances", 1))

    hit_ratio = round((1.0 - (reads / float(read_req))) * 100.0, 3) if read_req > 0 else 100.0
    free_ratio = round((pages_free / float(pages_total)) * 100.0, 2) if pages_total > 0 else 0.0
    dirty_ratio = round((pages_dirty / float(pages_total)) * 100.0, 2) if pages_total > 0 else 0.0

    host_ram_bytes = _get_available_ram_bytes()
    target_bp_bytes = int(host_ram_bytes * (target_ram_pct / 100.0)) if host_ram_bytes else None

    recommendations = []
    status_label = "OPTIMAL"

    if hit_ratio < 95.0:
        status_label = "UNDERSIZED"
        new_size = int(bp_size * 1.5)
        if target_bp_bytes is not None and new_size > target_bp_bytes:
            new_size = max(bp_size, target_bp_bytes)
        if target_bp_bytes is not None and bp_size >= target_bp_bytes:
            recommendations.append({
                "action": f"Review workload indexing before exceeding target RAM ceiling ({target_ram_pct}% = {target_bp_bytes} bytes).",
                "rollback": None,
                "reason": f"Hit ratio ({hit_ratio}%) is below 95% threshold, while buffer pool ({bp_size} bytes) already meets target {target_ram_pct}% RAM ceiling ({target_bp_bytes} bytes).",
                "requires_restart": False
            })
        else:
            recommendations.append({
                "action": f"SET GLOBAL innodb_buffer_pool_size = {new_size}",
                "rollback": f"SET GLOBAL innodb_buffer_pool_size = {bp_size}",
                "reason": f"Hit ratio ({hit_ratio}%) is below 95% threshold. Increasing buffer pool size reduces disk I/O.",
                "requires_restart": False
            })
    elif target_bp_bytes is not None and bp_size > target_bp_bytes:
        status_label = "OVERSIZED"
        recommendations.append({
            "action": f"SET GLOBAL innodb_buffer_pool_size = {target_bp_bytes}",
            "rollback": f"SET GLOBAL innodb_buffer_pool_size = {bp_size}",
            "reason": f"Allocated buffer pool ({bp_size} bytes) exceeds target {target_ram_pct}% of available RAM ({target_bp_bytes} bytes).",
            "requires_restart": False
        })
    elif free_ratio > 40.0 and dataset_bytes > 0 and bp_size > dataset_bytes * 2:
        status_label = "OVERSIZED"
        recommendations.append({
            "action": "Consider reducing innodb_buffer_pool_size to reclaim RAM for OS caching.",
            "rollback": None,
            "reason": f"Free buffer pool pages ({free_ratio}%) indicate over-allocation relative to dataset ({dataset_bytes} bytes).",
            "requires_restart": False
        })

    if include_dirty and dirty_ratio > 75.0:
        status_label = "DIRTY_STALL"
        recommendations.append({
            "action": "SET GLOBAL innodb_max_dirty_pages_pct = 70",
            "rollback": "SET GLOBAL innodb_max_dirty_pages_pct = 90",
            "reason": f"Dirty page ratio ({dirty_ratio}%) is above 75%. Flushing aggressive tuning recommended to prevent write stalls.",
            "requires_restart": False
        })

    if bp_size >= 1073741824 and instances < 8:
        recommendations.append({
            "action": "SET GLOBAL innodb_buffer_pool_instances = 8",
            "rollback": f"SET GLOBAL innodb_buffer_pool_instances = {instances}",
            "reason": "For buffer pool >= 1GB, allocating multiple instances reduces mutex lock contention across threads.",
            "requires_restart": True
        })

    metrics = {
        "hit_ratio_pct": hit_ratio,
        "allocated_bytes": bp_size,
        "allocated_human": f"{round(bp_size / (1024*1024), 2)} MB",
        "dataset_bytes": dataset_bytes,
        "dataset_human": f"{round(dataset_bytes / (1024*1024), 2)} MB",
        "free_pages_pct": free_ratio,
        "dirty_pages_pct": dirty_ratio,
        "instances": instances,
        "target_ram_percentage": target_ram_pct
    }
    if target_bp_bytes is not None:
        metrics["target_buffer_pool_bytes"] = target_bp_bytes

    result = {
        "status": status_label,
        "metrics": metrics,
        "recommendations": recommendations
    }

    return {"content": [{"type": "text", "text": json.dumps(result, indent=2)}]}

def handle_diagnose_replication_lag(arguments):
    if not isinstance(arguments, dict):
        arguments = {}

    max_lag = int(arguments.get("max_acceptable_lag_seconds", 30))
    channel = arguments.get("channel_name", "")
    if channel:
        channel = str(channel).strip()
        if not re.match(r"^[A-Za-z0-9_-]{1,64}$", channel):
            return {
                "isError": True,
                "content": [{"type": "text", "text": f"Invalid channel_name '{channel}'. Must match ^[A-Za-z0-9_-]{{1,64}}$"}]
            }

    # Try SHOW REPLICA STATUS first, fallback to SHOW SLAVE STATUS
    channel_clause = f" FOR CHANNEL '{channel}'" if channel else ""
    rep_query = f"SHOW REPLICA STATUS{channel_clause}\\G"
    success, out = run_db_query(rep_query)
    if not success or not out or ("Slave_IO_Running" not in out and "Replica_IO_Running" not in out):
        rep_query = f"SHOW SLAVE STATUS{channel_clause}\\G"
        success, out = run_db_query(rep_query)

    vars_query = "SHOW GLOBAL VARIABLES WHERE Variable_name IN ('replica_parallel_workers', 'slave_parallel_workers', 'replica_parallel_type', 'slave_parallel_type', 'gtid_mode');"
    _, vars_out = run_db_query(vars_query)
    vars_dict = {}
    if vars_out:
        for line in vars_out.strip().splitlines():
            p = line.split()
            if len(p) >= 2:
                vars_dict[p[0]] = p[1]

    workers = int(vars_dict.get("replica_parallel_workers") or vars_dict.get("slave_parallel_workers") or 0)
    worker_type = vars_dict.get("replica_parallel_type") or vars_dict.get("slave_parallel_type") or "DATABASE"
    gtid_mode = vars_dict.get("gtid_mode", "OFF")

    if not success or not out or ("Slave_IO_Running" not in out and "Replica_IO_Running" not in out):
        # Standalone node or no replication configured
        result = {
            "status": "NOT_A_REPLICA",
            "message": "Instance is operating as standalone primary or replication is not configured.",
            "metrics": {
                "is_replica": False,
                "parallel_workers": workers,
                "gtid_mode": gtid_mode
            },
            "recommendations": []
        }
        return {"content": [{"type": "text", "text": json.dumps(result, indent=2)}]}

    # Parse key-value pairs from \\G output
    repl_data = {}
    for line in out.strip().splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            repl_data[k.strip()] = v.strip()

    io_running = repl_data.get("Slave_IO_Running") or repl_data.get("Replica_IO_Running") or "No"
    sql_running = repl_data.get("Slave_SQL_Running") or repl_data.get("Replica_SQL_Running") or "No"
    sec_behind = repl_data.get("Seconds_Behind_Master") or repl_data.get("Seconds_Behind_Source")
    last_io_err = repl_data.get("Last_IO_Error") or ""
    last_sql_err = repl_data.get("Last_SQL_Error") or ""
    last_sql_errno = int(repl_data.get("Last_SQL_Errno") or 0)

    lag_seconds = int(sec_behind) if (sec_behind is not None and str(sec_behind).isdigit()) else None

    recommendations = []
    status_label = "HEALTHY"

    if io_running != "Yes" or sql_running != "Yes":
        status_label = "THREAD_FAILED"
        err_detail = last_sql_err if sql_running != "Yes" else last_io_err
        recommendations.append({
            "action": "START REPLICA;",
            "rollback": "STOP REPLICA;",
            "reason": f"Replication thread failure detected (IO: {io_running}, SQL: {sql_running}). Error #{last_sql_errno}: {err_detail}",
            "requires_restart": False
        })
    elif lag_seconds is not None and lag_seconds > max_lag:
        status_label = "DEGRADED_LAG"
        if workers == 0:
            recommendations.append({
                "action": "SET GLOBAL replica_parallel_workers = 4",
                "rollback": f"SET GLOBAL replica_parallel_workers = {workers}",
                "reason": f"Replication lag ({lag_seconds}s) exceeds threshold ({max_lag}s). Parallel workers are currently disabled.",
                "requires_restart": False
            })
        else:
            recommendations.append({
                "action": f"SET GLOBAL replica_parallel_workers = {workers * 2}",
                "rollback": f"SET GLOBAL replica_parallel_workers = {workers}",
                "reason": f"Replication lag ({lag_seconds}s) exceeds threshold ({max_lag}s). Increasing parallel workers from {workers} to {workers * 2}.",
                "requires_restart": False
            })

    result = {
        "status": status_label,
        "metrics": {
            "is_replica": True,
            "io_thread_running": io_running == "Yes",
            "sql_thread_running": sql_running == "Yes",
            "lag_seconds": lag_seconds,
            "parallel_workers": workers,
            "parallel_type": worker_type,
            "gtid_mode": gtid_mode,
            "last_sql_errno": last_sql_errno,
            "last_sql_error": last_sql_err,
            "last_io_error": last_io_err
        },
        "recommendations": recommendations
    }

    return {"content": [{"type": "text", "text": json.dumps(result, indent=2)}]}

def handle_detect_fragmented_tables(arguments):
    if not isinstance(arguments, dict):
        arguments = {}

    min_frag_pct = float(arguments.get("min_fragmentation_pct", 20.0))
    min_size_mb = float(arguments.get("min_table_size_mb", 10.0))
    min_size_bytes = int(min_size_mb * 1024 * 1024)
    schema_filter = str(arguments.get("schema_filter") or "").strip()
    if schema_filter:
        if not re.match(r"^[A-Za-z0-9_$-]{1,64}$", schema_filter):
            return {
                "isError": True,
                "content": [{"type": "text", "text": f"Invalid schema_filter '{schema_filter}'. Must match ^[A-Za-z0-9_$-]{{1,64}}$"}]
            }

    where_clauses = [
        "TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')",
        "(DATA_LENGTH + INDEX_LENGTH + DATA_FREE) >= %d" % min_size_bytes
    ]
    if schema_filter:
        escaped_schema = schema_filter.replace("'", "''")
        where_clauses.append("TABLE_SCHEMA = '%s'" % escaped_schema)

    query = (
        "SELECT TABLE_SCHEMA, TABLE_NAME, IFNULL(ENGINE, 'UNKNOWN'), "
        "DATA_LENGTH, INDEX_LENGTH, DATA_FREE, IFNULL(TABLE_ROWS, 0) "
        "FROM information_schema.TABLES WHERE %s "
        "ORDER BY DATA_FREE DESC LIMIT 100;" % " AND ".join(where_clauses)
    )

    success, out = run_db_query(query)
    tables_list = []
    total_reclaimable_bytes = 0

    if success and out:
        for line in out.strip().splitlines():
            parts = line.split("\t")
            if len(parts) < 6:
                parts = line.split()
            if len(parts) >= 6:
                schema_name = parts[0]
                tbl_name = parts[1]
                engine = parts[2]
                try:
                    data_len = int(parts[3])
                    idx_len = int(parts[4])
                    data_free = int(parts[5])
                    tbl_rows = int(parts[6]) if len(parts) > 6 else 0
                except ValueError:
                    continue

                total_space = data_len + idx_len + data_free
                if total_space <= 0:
                    continue

                frag_pct = round((data_free / float(total_space)) * 100.0, 2)
                if frag_pct >= min_frag_pct:
                    is_high_impact = total_space >= (5 * 1024 * 1024 * 1024)
                    reclaimable = data_free
                    total_reclaimable_bytes += reclaimable

                    clean_schema = schema_name.replace("`", "``")
                    clean_tbl = tbl_name.replace("`", "``")
                    optimize_stmt = f"OPTIMIZE TABLE `{clean_schema}`.`{clean_tbl}`;"

                    tables_list.append({
                        "schema": schema_name,
                        "table": tbl_name,
                        "engine": engine,
                        "total_size_bytes": total_space,
                        "total_size_human": f"{round(total_space / (1024*1024), 2)} MB",
                        "data_free_bytes": data_free,
                        "data_free_human": f"{round(data_free / (1024*1024), 2)} MB",
                        "fragmentation_pct": frag_pct,
                        "rows": tbl_rows,
                        "is_high_impact": is_high_impact,
                        "recommended_action": optimize_stmt
                    })

    status_label = "FRAGMENTATION_DETECTED" if tables_list else "OPTIMAL"

    result = {
        "status": status_label,
        "metrics": {
            "fragmented_table_count": len(tables_list),
            "total_reclaimable_bytes": total_reclaimable_bytes,
            "total_reclaimable_human": f"{round(total_reclaimable_bytes / (1024*1024), 2)} MB",
            "evaluated_min_size_mb": min_size_mb,
            "evaluated_min_fragmentation_pct": min_frag_pct
        },
        "fragmented_tables": tables_list
    }

    return {"content": [{"type": "text", "text": json.dumps(result, indent=2)}]}

# Registry of Tools & Schemas
TOOLS_CATALOG = [
    {
        "name": "get_latest_audit",
        "description": "Get the latest cached audit findings in structured JSON format without querying the database.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "additionalProperties": False
        }
    },
    {
        "name": "run_audit",
        "description": "Execute a fresh database audit via MySQLTuner Perl engine and return structured JSON recommendations immediately.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "additionalProperties": False
        }
    },
    {
        "name": "analyze_buffer_pool",
        "description": "Deeply analyze InnoDB Buffer Pool caching efficiency, hit ratio, dirty pages, and concurrency sizing.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "target_ram_percentage": {
                    "type": "number",
                    "description": "Target percentage of available host RAM dedicated to InnoDB Buffer Pool (default: 75)."
                },
                "include_dirty_pages": {
                    "type": "boolean",
                    "description": "Include dirty page write stall analysis (default: true)."
                }
            },
            "additionalProperties": False
        }
    },
    {
        "name": "diagnose_replication_lag",
        "description": "Diagnose MySQL / MariaDB replication latency, IO/SQL thread failures, GTID synchronization, and parallel workers.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "max_acceptable_lag_seconds": {
                    "type": "integer",
                    "description": "Threshold in seconds above which replication is considered degraded (default: 30)."
                },
                "channel_name": {
                    "type": "string",
                    "description": "Multi-source replication channel name (optional, default empty for default channel)."
                }
            },
            "additionalProperties": False
        }
    },
    {
        "name": "detect_fragmented_tables",
        "description": "Detect tables with high storage fragmentation, calculate reclaimable space, and recommend defragmentation actions.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "min_fragmentation_pct": {
                    "type": "number",
                    "description": "Minimum fragmentation percentage to trigger reporting (default: 20)."
                },
                "min_table_size_mb": {
                    "type": "number",
                    "description": "Minimum table size in MB to filter out trivial tables (default: 10)."
                },
                "schema_filter": {
                    "type": "string",
                    "description": "Optional schema name to restrict the scan (default empty for all user schemas)."
                }
            },
            "additionalProperties": False
        }
    },
    {
        "name": "apply_recommendation",
        "description": "Apply a safe database recommendation (e.g. SET GLOBAL or ALTER TABLE) with transactional state tracking.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "statement": {
                    "type": "string",
                    "description": "The exact SQL statement to execute (must start with SET GLOBAL, SET PERSIST, ALTER TABLE, OPTIMIZE TABLE, or ANALYZE TABLE)."
                },
                "variable_name": {
                    "type": "string",
                    "description": "The global variable name being modified (optional, used to capture baseline value for rollback)."
                }
            },
            "required": ["statement"],
            "additionalProperties": False
        }
    },
    {
        "name": "rollback_recommendation",
        "description": "Revert a previously applied database recommendation using its recorded transaction statement ID.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "statement_id": {
                    "type": "string",
                    "description": "The Statement ID returned when apply_recommendation was called."
                }
            },
            "required": ["statement_id"],
            "additionalProperties": False
        }
    }
]

TOOL_HANDLERS = {
    "get_latest_audit": handle_get_latest_audit,
    "run_audit": handle_run_audit,
    "analyze_buffer_pool": handle_analyze_buffer_pool,
    "diagnose_replication_lag": handle_diagnose_replication_lag,
    "detect_fragmented_tables": handle_detect_fragmented_tables,
    "apply_recommendation": handle_apply_recommendation,
    "rollback_recommendation": handle_rollback_recommendation
}

# Core JSON-RPC 2.0 Dispatcher
def dispatch_jsonrpc(req_raw):
    """
    Parses and dispatches a JSON-RPC 2.0 request.
    Returns (response_dict_or_None, is_notification)
    """
    if isinstance(req_raw, str):
        try:
            req = json.loads(req_raw)
        except Exception as e:
            return {
                "jsonrpc": "2.0",
                "error": {"code": -32700, "message": f"Parse error: {str(e)}"},
                "id": None
            }, False
    elif isinstance(req_raw, dict):
        req = req_raw
    else:
        return {
            "jsonrpc": "2.0",
            "error": {"code": -32600, "message": "Invalid Request: Payload must be a JSON object."},
            "id": None
        }, False

    if not isinstance(req, dict):
        return {
            "jsonrpc": "2.0",
            "error": {"code": -32600, "message": "Invalid Request: Expected JSON object."},
            "id": None
        }, False

    req_id = req.get("id")
    is_notification = "id" not in req
    method = req.get("method")

    if not method or not isinstance(method, str):
        return {
            "jsonrpc": "2.0",
            "error": {"code": -32600, "message": "Invalid Request: 'method' string is required."},
            "id": req_id
        }, is_notification

    # 1. Initialize
    if method == "initialize":
        result = {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {
                "tools": {},
                "resources": {},
                "prompts": {}
            },
            "serverInfo": {
                "name": "mysqltuner-mcp",
                "version": SERVER_VERSION
            }
        }
        return {"jsonrpc": "2.0", "result": result, "id": req_id}, is_notification

    # 2. Tools list
    elif method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "result": {"tools": TOOLS_CATALOG},
            "id": req_id
        }, is_notification

    # 3. Tools call
    elif method == "tools/call":
        params = req.get("params")
        if not isinstance(params, dict):
            return {
                "jsonrpc": "2.0",
                "error": {"code": -32602, "message": "Invalid params: 'params' must be an object."},
                "id": req_id
            }, is_notification

        name = params.get("name")
        arguments = params.get("arguments", {})

        if not name or name not in TOOL_HANDLERS:
            return {
                "jsonrpc": "2.0",
                "result": {"isError": True, "content": [{"type": "text", "text": f"Unknown tool: '{name}'"}]},
                "id": req_id
            }, is_notification

        try:
            handler_res = TOOL_HANDLERS[name](arguments)
            return {
                "jsonrpc": "2.0",
                "result": handler_res,
                "id": req_id
            }, is_notification
        except Exception as e:
            return {
                "jsonrpc": "2.0",
                "error": {"code": -32603, "message": f"Internal error during tool execution: {str(e)}"},
                "id": req_id
            }, is_notification

    # 4. Resources list
    elif method == "resources/list":
        return {
            "jsonrpc": "2.0",
            "result": {
                "resources": [
                    {
                        "uri": "mysqltuner://reports/latest.json",
                        "name": "Latest JSON report",
                        "description": "Comprehensive structured JSON output from the most recent database audit.",
                        "mimeType": "application/json"
                    },
                    {
                        "uri": "mysqltuner://reports/latest.html",
                        "name": "Latest HTML dashboard",
                        "description": "Interactive HTML dashboard with visual metrics and recommendations.",
                        "mimeType": "text/html"
                    }
                ]
            },
            "id": req_id
        }, is_notification

    # 5. Resources read
    elif method == "resources/read":
        params = req.get("params", {})
        uri = params.get("uri") if isinstance(params, dict) else None

        if not uri:
            return {
                "jsonrpc": "2.0",
                "error": {"code": -32602, "message": "Invalid params: 'uri' parameter is required."},
                "id": req_id
            }, is_notification

        content = ""
        mime = "text/plain"
        target_path = None
        if uri == "mysqltuner://reports/latest.json":
            target_path = LATEST_JSON
            mime = "application/json"
        elif uri == "mysqltuner://reports/latest.html":
            target_path = LATEST_HTML
            mime = "text/html"

        with CACHE_LOCK:
            if target_path and os.path.exists(target_path):
                try:
                    with open(target_path, "r", encoding="utf-8") as f:
                        content = f.read()
                except Exception as e:
                    content = f"Error reading resource: {str(e)}"
            else:
                content = "Resource not found or cache is empty."

        return {
            "jsonrpc": "2.0",
            "result": {
                "contents": [
                    {
                        "uri": uri,
                        "mimeType": mime,
                        "text": content
                    }
                ]
            },
            "id": req_id
        }, is_notification

    # 6. Unknown method
    else:
        return {
            "jsonrpc": "2.0",
            "error": {"code": -32601, "message": f"Method not found: '{method}'"},
            "id": req_id
        }, is_notification

# SSE HTTP Transport Server
class MCPSSEHandler(BaseHTTPRequestHandler):
    sessions = {}

    def log_message(self, format, *args):
        # Suppress noisy standard HTTP logging to stdout
        sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), format % args))

    def check_auth(self):
        token = os.environ.get("MCP_AUTH_TOKEN")
        if not token:
            return True
        auth = self.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            return auth[7:].strip() == token
        return False

    def do_HEAD(self):
        if not self.check_auth():
            self.send_response(401)
            self.end_headers()
            return
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/sse":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.end_headers()
        elif parsed.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        if not self.check_auth():
            self.send_response(401)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Unauthorized"}).encode("utf-8"))
            return
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/sse":
            session_id = str(uuid.uuid4())
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.end_headers()

            # Announce endpoint event
            endpoint_msg = f"event: endpoint\ndata: /message?sessionId={session_id}\n\n"
            self.wfile.write(endpoint_msg.encode("utf-8"))
            self.wfile.flush()

            # Keep connection alive
            try:
                while True:
                    time.sleep(15)
                    self.wfile.write(b": ping\n\n")
                    self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass
        elif parsed.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "healthy", "version": SERVER_VERSION}).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if not self.check_auth():
            self.send_response(401)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Unauthorized"}).encode("utf-8"))
            return
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/message":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length).decode("utf-8")
            resp, is_notification = dispatch_jsonrpc(body)

            if is_notification:
                self.send_response(202)
                self.end_headers()
            else:
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(resp).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

def run_sse_server(host="127.0.0.1", port=8000):
    global READ_ONLY
    if not os.environ.get("MCP_AUTH_TOKEN"):
        READ_ONLY = True
    server = ThreadingHTTPServer((host, port), MCPSSEHandler)
    server.daemon_threads = True
    sys.stderr.write(f"MySQLTuner MCP SSE Server listening on http://{host}:{port}/sse (read_only={READ_ONLY})\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

# Stdio Loop
def main_stdio():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        resp, is_notification = dispatch_jsonrpc(line)
        if not is_notification and resp is not None:
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()

def daemon_loop():
    while True:
        run_mysqltuner_cmd()
        time.sleep(AUDIT_INTERVAL_HOURS * 3600)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="MySQLTuner Model Context Protocol (MCP) Server")
    parser.add_argument("--daemon", action="store_true", help="Run background periodic auditing loop")
    parser.add_argument("--sse", action="store_true", help="Start HTTP SSE server instead of stdio")
    parser.add_argument("--host", default="127.0.0.1", help="HTTP host for SSE server (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=8000, help="HTTP port for SSE server (default: 8000)")

    args = parser.parse_args()

    if args.daemon:
        daemon_loop()
    elif args.sse:
        t = threading.Thread(target=daemon_loop, daemon=True)
        t.start()
        run_sse_server(host=args.host, port=args.port)
    else:
        t = threading.Thread(target=daemon_loop, daemon=True)
        t.start()
        main_stdio()
