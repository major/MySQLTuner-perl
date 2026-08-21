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
SERVER_VERSION = "2.9.2"
PROTOCOL_VERSION = "2024-11-05"

# Ensure cache directory exists
os.makedirs(CACHE_DIR, exist_ok=True)

STATE_FILE = os.path.join(CACHE_DIR, "state.json")
LATEST_JSON = os.path.join(CACHE_DIR, "latest.json")
LATEST_HTML = os.path.join(CACHE_DIR, "latest.html")

# State Management
def load_state():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"applied": []}

def save_state(state):
    try:
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(state, f, indent=2)
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

    args = ["/usr/bin/perl", script_path, "--prettyjson", "--reportfile", LATEST_HTML]

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
        with open(LATEST_JSON, "w", encoding="utf-8") as f:
            f.write(result.stdout)
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        err_msg = f"MySQLTuner failed with code {e.returncode}: {e.stderr or e.stdout}"
        return False, err_msg
    except Exception as e:
        return False, str(e)

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

    # Strip block comments /* ... */
    stmt = re.sub(r'/\*.*?\*/', '', stmt, flags=re.DOTALL).strip()

    if not stmt:
        return False, "Statement is empty after comment stripping.", ""

    # Check for multi-statements (semicolons separating non-empty statements)
    parts = [p.strip() for p in stmt.split(";") if p.strip()]
    if len(parts) > 1:
        return False, "Multiple SQL statements in a single execution are strictly prohibited for safety.", ""

    single_stmt = parts[0] if parts else stmt
    normalized = single_stmt.upper().strip()

    # Disallow destructive keywords anywhere in statement
    blacklisted = [
        r'\bDROP\b', r'\bDELETE\b', r'\bTRUNCATE\b', r'\bINSERT\b', r'\bUPDATE\b',
        r'\bGRANT\b', r'\bREVOKE\b', r'\bCREATE\b', r'\bREPLACE\b', r'\bEXECUTE\b',
        r'\bCALL\b', r'\bLOAD_FILE\b', r'\bINTO\s+OUTFILE\b', r'\bINTO\s+DUMPFILE\b',
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

    def do_HEAD(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/sse":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
        elif parsed.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/sse":
            session_id = str(uuid.uuid4())
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.send_header("Access-Control-Allow-Origin", "*")
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
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(json.dumps(resp).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

def run_sse_server(host="0.0.0.0", port=8000):
    server = ThreadingHTTPServer((host, port), MCPSSEHandler)
    server.daemon_threads = True
    sys.stderr.write(f"MySQLTuner MCP SSE Server listening on http://{host}:{port}/sse\n")
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
    parser.add_argument("--host", default="0.0.0.0", help="HTTP host for SSE server (default: 0.0.0.0)")
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
