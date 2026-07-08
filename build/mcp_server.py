#!/usr/bin/env python3
import sys
import os
import json
import time
import threading
import subprocess
import traceback

# Config defaults
CACHE_DIR = os.environ.get("CACHE_DIR", "/var/cache/mysqltuner")
AUDIT_INTERVAL_HOURS = float(os.environ.get("AUDIT_INTERVAL_HOURS", "12"))
READ_ONLY = os.environ.get("READ_ONLY", "false").lower() == "true"

# Ensure cache directory exists
os.makedirs(CACHE_DIR, exist_ok=True)

STATE_FILE = os.path.join(CACHE_DIR, "state.json")
LATEST_JSON = os.path.join(CACHE_DIR, "latest.json")
LATEST_HTML = os.path.join(CACHE_DIR, "latest.html")

def load_state():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {"applied": []}

def save_state(state):
    try:
        with open(STATE_FILE, "w") as f:
            json.dump(state, f, indent=2)
    except Exception:
        pass

def run_mysqltuner_cmd():
    # Build connection args from environment variables
    args = ["/usr/bin/perl", "mysqltuner.pl", "--prettyjson", "--reportfile", LATEST_HTML]
    
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
        # Run process and capture stdout
        result = subprocess.run(args, capture_output=True, text=True, check=True)
        # Save to latest.json
        with open(LATEST_JSON, "w") as f:
            f.write(result.stdout)
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        err_msg = f"MySQLTuner failed with code {e.returncode}: {e.stderr}"
        return False, err_msg
    except Exception as e:
        return False, str(e)

def daemon_loop():
    while True:
        run_mysqltuner_cmd()
        # Sleep interval converted to seconds
        time.sleep(AUDIT_INTERVAL_HOURS * 3600)

# DB query helper
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
        return False, e.stderr.strip()

# MCP Tool handlers
def handle_get_latest_audit():
    if os.path.exists(LATEST_JSON):
        try:
            with open(LATEST_JSON, "r") as f:
                return {"content": [{"type": "text", "text": f.read()}]}
        except Exception as e:
            return {"isError": True, "content": [{"type": "text", "text": f"Error reading cached audit: {str(e)}"}]}
    return {"content": [{"type": "text", "text": "No cached audit findings found. Try running run_audit first."}]}

def handle_run_audit():
    success, output = run_mysqltuner_cmd()
    if success:
        return {"content": [{"type": "text", "text": output}]}
    return {"isError": True, "content": [{"type": "text", "text": f"Failed to execute audit: {output}"}]}

def handle_apply_recommendation(arguments):
    if READ_ONLY:
        return {"isError": True, "content": [{"type": "text", "text": "Execution rejected: MCP server is running in read-only mode."}]}
        
    statement = arguments.get("statement")
    if not statement:
        return {"isError": True, "content": [{"type": "text", "text": "Missing parameter: 'statement' is required."}]}
        
    # Safety Check: Allow only SET GLOBAL, ALTER TABLE, OPTIMIZE TABLE
    clean_stmt = statement.strip().upper()
    is_safe = (clean_stmt.startswith("SET GLOBAL") or 
               clean_stmt.startswith("ALTER TABLE") or 
               clean_stmt.startswith("OPTIMIZE TABLE"))
               
    if not is_safe:
        return {"isError": True, "content": [{"type": "text", "text": f"Execution rejected: Statement '{statement}' is not recognized as a safe configuration adjustment."}]}
        
    # If setting a global variable, fetch its current value for rollback
    var_name = arguments.get("variable_name")
    old_value = None
    if var_name:
        success, val = run_db_query(f"SELECT @@global.{var_name}")
        if success:
            old_value = val

    # Execute statement
    success, err = run_db_query(statement)
    if not success:
        return {"isError": True, "content": [{"type": "text", "text": f"SQL Execution failed: {err}"}]}
        
    # Save to transaction state
    state = load_state()
    stmt_id = str(int(time.time()))
    state["applied"].append({
        "id": stmt_id,
        "statement": statement,
        "variable_name": var_name,
        "old_value": old_value,
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
    })
    save_state(state)
    
    return {"content": [{"type": "text", "text": f"Success: Statement executed successfully. Statement ID: {stmt_id}"}]}

def handle_rollback_recommendation(arguments):
    if READ_ONLY:
        return {"isError": True, "content": [{"type": "text", "text": "Execution rejected: MCP server is running in read-only mode."}]}
        
    stmt_id = arguments.get("statement_id")
    if not stmt_id:
        return {"isError": True, "content": [{"type": "text", "text": "Missing parameter: 'statement_id' is required."}]}
        
    state = load_state()
    target = None
    for entry in state["applied"]:
        if entry["id"] == stmt_id:
            target = entry
            break
            
    if not target:
        return {"isError": True, "content": [{"type": "text", "text": f"Error: Statement ID {stmt_id} not found in state registry."}]}
        
    var_name = target.get("variable_name")
    old_value = target.get("old_value")
    
    if var_name and old_value is not None:
        # Revert global variable
        rollback_stmt = f"SET GLOBAL {var_name} = {old_value}"
        success, err = run_db_query(rollback_stmt)
        if not success:
            return {"isError": True, "content": [{"type": "text", "text": f"Rollback SQL failed: {err}"}]}
    else:
        return {"isError": True, "content": [{"type": "text", "text": "Cannot rollback: This statement type does not support automatic rollback."}]}
        
    # Remove from state
    state["applied"].remove(target)
    save_state(state)
    
    return {"content": [{"type": "text", "text": f"Success: Rollback executed successfully: {rollback_stmt}"}]}

# MCP Protocol handler Loop
def main_mcp():
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break
            req = json.loads(line)
            method = req.get("method")
            id_ = req.get("id")
            
            if method == "initialize":
                resp = {
                    "jsonrpc": "2.0",
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {
                            "tools": {},
                            "resources": {}
                        },
                        "serverInfo": {
                            "name": "mysqltuner-mcp",
                            "version": "2.9.1"
                        }
                    },
                    "id": id_
                }
            elif method == "tools/list":
                resp = {
                    "jsonrpc": "2.0",
                    "result": {
                        "tools": [
                            {
                                "name": "get_latest_audit",
                                "description": "Get the latest cached audit findings in JSON format."
                            },
                            {
                                "name": "run_audit",
                                "description": "Execute a fresh database audit and return findings immediately."
                            },
                            {
                                "name": "apply_recommendation",
                                "description": "Apply a safe database recommendation (e.g. SET GLOBAL or ALTER TABLE).",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "statement": {"type": "string", "description": "The SQL statement to execute."},
                                        "variable_name": {"type": "string", "description": "The global variable name being set (optional, for rollback)."}
                                    },
                                    "required": ["statement"]
                                }
                            },
                            {
                                "name": "rollback_recommendation",
                                "description": "Revert a previously applied database recommendation.",
                                "inputSchema": {
                                    "type": "object",
                                    "properties": {
                                        "statement_id": {"type": "string", "description": "The Statement ID returned during execution."}
                                    },
                                    "required": ["statement_id"]
                                }
                            }
                        ]
                    },
                    "id": id_
                }
            elif method == "tools/call":
                params = req.get("params", {})
                name = params.get("name")
                arguments = params.get("arguments", {})
                
                if name == "get_latest_audit":
                    res = handle_get_latest_audit()
                elif name == "run_audit":
                    res = handle_run_audit()
                elif name == "apply_recommendation":
                    res = handle_apply_recommendation(arguments)
                elif name == "rollback_recommendation":
                    res = handle_rollback_recommendation(arguments)
                else:
                    res = {"isError": True, "content": [{"type": "text", "text": f"Unknown tool: {name}"}]}
                    
                resp = {
                    "jsonrpc": "2.0",
                    "result": res,
                    "id": id_
                }
            elif method == "resources/list":
                resp = {
                    "jsonrpc": "2.0",
                    "result": {
                        "resources": [
                            {
                                "uri": "mysqltuner://reports/latest.json",
                                "name": "Latest JSON report",
                                "mimeType": "application/json"
                            },
                            {
                                "uri": "mysqltuner://reports/latest.html",
                                "name": "Latest HTML dashboard",
                                "mimeType": "text/html"
                            }
                        ]
                    },
                    "id": id_
                }
            elif method == "resources/read":
                params = req.get("params", {})
                uri = params.get("uri")
                
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
                        with open(target_path, "r") as f:
                            content = f.read()
                    except Exception as e:
                        content = f"Error reading resource: {str(e)}"
                else:
                    content = "Resource not found or empty."
                    
                resp = {
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
                    "id": id_
                }
            else:
                resp = {
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32601,
                        "message": f"Method not found: {method}"
                    },
                    "id": id_
                }
                
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()
        except Exception as e:
            sys.stderr.write(traceback.format_exc() + "\n")
            sys.stderr.flush()

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--daemon":
        # Run daemon auditing in foreground
        daemon_loop()
    else:
        # Start daemon interval thread
        t = threading.Thread(target=daemon_loop, daemon=True)
        t.start()
        # Serve MCP stdio
        main_mcp()
