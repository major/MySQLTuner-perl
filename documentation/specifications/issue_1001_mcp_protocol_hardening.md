# Issue #1001: MCP Protocol Hardening, Robust Error Handling & SSE Transport Support

**Type:** Feature / Hardening  
**Component:** `build/mcp_server.py`, `tests/unit_mcp_protocol.t`  
**Assignee:** jmrenouard  
**Labels:** `mcp`, `protocol`, `security`, `sse`, `json-rpc`  

## 🎯 Description & Objectives
The Model Context Protocol (MCP) server for MySQLTuner needs to adhere strictly to the MCP 2024-11-05 specification and JSON-RPC 2.0 (RFC 4627 / 7159).
Key requirements:
1. **Full JSON-RPC 2.0 Compliance**:
   - Standard error codes: `-32700` (Parse error), `-32600` (Invalid Request), `-32601` (Method not found), `-32602` (Invalid params), `-32603` (Internal error).
   - Proper request ID preservation and type support (string, integer, null).
   - Strict notification support (requests without `id` do not return a response).
2. **Dual Transport Support**:
   - `stdio` (default standard input/output streaming).
   - `sse` (HTTP Server-Sent Events with `/sse` endpoint and `/message` POST endpoint using Python standard library `http.server` for zero external dependencies).
3. **Robust Input Parsing & Security Sanitization**:
   - Strict rejection of multi-statement injection, semicolon splitting, dangerous commands (`DROP`, `DELETE`, `TRUNCATE`, `GRANT`, `REVOKE`, `SYSTEM`).
   - Clean SQL comment stripping before validation.
4. **Complete Schema Definitions**:
   - All tools must expose valid JSON Schemas for `inputSchema` with `type: "object"` and structured parameter validation.

## 🧪 Acceptance Criteria
- [x] JSON-RPC 2.0 error handling adheres to standard codes.
- [x] Support `--sse --port <PORT>` and `--stdio` modes.
- [x] Unit test suite `tests/unit_mcp_protocol.t` validates stdio and SSE interfaces.
- [x] Zero external Python library dependencies (pure standard library: `json`, `http.server`, `urllib`, `threading`, `subprocess`).
