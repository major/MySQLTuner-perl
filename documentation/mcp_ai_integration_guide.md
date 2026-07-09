# AI & MCP Integration Guide for MySQL Optimization

This guide explains how to set up the Model Context Protocol (MCP) server for MySQLTuner and configure AI agents (e.g. Claude Desktop, Cursor, VS Code Extensions) to run deep, automated performance audits and apply safe, rollback-enabled tuning configurations.

---

## 📦 Part 1: Setting Up the MCP Server

The MySQLTuner MCP server acts as an intermediary bridge between your database and AI agents, exposing database telemetry and actionable SQL recommendations over standard I/O (stdio).

### Method A: Dockerized Deployment (Recommended)
This method containerizes the entire toolchain (Perl, Python 3, and mysql client utilities) to ensure compatibility.

```bash
docker run -d \
  --name mysqltuner-mcp \
  -e DB_HOST=your-database-host \
  -e DB_PORT=3306 \
  -e DB_USER=tuner_user \
  -e DB_PASSWORD=your_password \
  -e AUDIT_INTERVAL_HOURS=6 \
  -v /var/cache/mysqltuner:/var/cache/mysqltuner \
  mysqltuner-mcp
```

### Method B: Local Execution (Without Docker)
Ensure Python 3 and Perl are installed locally, then run the script directly:
```bash
export DB_HOST="127.0.0.1"
export DB_USER="root"
export DB_PASSWORD="your_password"
export CACHE_DIR="./mcp_cache"

python3 build/mcp_server.py
```

---

## 🛠️ Part 2: Configuring AI Clients

Once the server is running, register it inside your preferred AI agent environment.

### 1. Claude Desktop Config
Add the server definition to your Claude Desktop configuration file:
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "mysqltuner": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-v",
        "/var/cache/mysqltuner:/var/cache/mysqltuner",
        "-e",
        "DB_HOST=host.docker.internal",
        "-e",
        "DB_USER=root",
        "-e",
        "DB_PASSWORD=secret",
        "mysqltuner-mcp"
      ]
    }
  }
}
```

### 2. Cursor IDE Config
1. Open Cursor and navigate to **Settings** -> **Features** -> **MCP**.
2. Click **+ Add New MCP Server**.
3. Fill in the parameters:
   - **Name**: `mysqltuner`
   - **Type**: `stdio`
   - **Command**: `python3 /path/to/MySQLTuner-perl/build/mcp_server.py`
4. Set environment variables in the terminal where Cursor was launched.

### 3. VS Code (Cline / Roo Code / Roo Cline)
Configure the extension settings `mcpSettings.json` to spawn the server:
```json
{
  "mcpServers": {
    "mysqltuner": {
      "command": "python3",
      "args": ["/path/to/MySQLTuner-perl/build/mcp_server.py"],
      "env": {
        "DB_HOST": "127.0.0.1",
        "DB_USER": "root",
        "DB_PASSWORD": "your_password"
      }
    }
  }
}
```

---

## 🔍 Part 3: Deep Database Tuning with AI

When connected, the AI agent has access to MySQLTuner findings and can cross-reference logs, memory allocations, and schema design to perform high-density optimizations.

### 1. Memory Allocation and Buffers
AI agents can parse the buffer pool allocations and compare them to physical RAM limits to prevent Out-Of-Memory (OOM) situations.
- **Agent Analysis**: Evaluates `pct_max_physical_memory` to verify if memory usage is safe.
- **Live Adjustment**: Executes `apply_recommendation` with `SET GLOBAL innodb_buffer_pool_size = <value>` if the database version supports dynamic buffer pool resizing (MySQL 5.7+).

### 2. Connection Saturation and Thread Cache
High connection spikes cause high thread creation overhead.
- **Agent Analysis**: Evaluates `max_connections` and matches it against `threads_created`.
- **Live Adjustment**: Sets `thread_cache_size` to reduce creation overhead:
  `SET GLOBAL thread_cache_size = 16;`

### 3. Index Profiling and Table Churn
- **Agent Analysis**: The agent queries table fragmentation and matches it with Performance Schema query logs.
- **Live Action**: Automatically schedules defragmentation for high-churn tables:
  `OPTIMIZE TABLE schema_name.table_name;`

---

## 🤖 Part 4: Advanced Prompt Engineering for AI Agents

To ensure the AI operates safely and acts as an expert DBA, prepend your conversations with the following System Prompt:

```markdown
You are a Senior Principal Database Administrator (DBA). You have access to the MySQLTuner MCP server.
Your core mission is to audit, analyze, and optimize the MySQL instance safely.

### Operating Rules:
1. **Always Verify Baseline**: Before executing any SQL changes, read the cached audit resources (`mysqltuner://reports/latest.json`).
2. **Classify by Risk**: Categorize recommendations. Apply 'Low' or 'Medium' risk adjustments dynamically. Never apply 'High' or 'Critical' recommendations (such as changes requiring a service restart or ALTER TABLE on tables > 10GB) without explicit user confirmation.
3. **Draft Rollbacks First**: Before invoking `apply_recommendation`, state the exact SQL statement to be executed AND the corresponding `rollback_statement` so the user is fully informed.
4. **Iterative Auditing**: After applying a recommendation, trigger `run_audit` to confirm that the indicator has improved. If performance metrics degrade or the audit flags unexpected regressions, immediately run `rollback_recommendation` using the returned Statement ID.
```
