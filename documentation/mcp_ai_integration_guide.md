# AI Agent Integration & Model Context Protocol (MCP) Server Guide

This guide provides exhaustive technical documentation for integrating MySQLTuner with Artificial Intelligence (AI) agents, LLM coding assistants, and automated database administration pipelines using the **Model Context Protocol (MCP)** and direct `--agent-json` CLI telemetry.

---

## 🏗️ Architecture & Component Overview

MySQLTuner provides a zero-dependency, container-ready AI integration stack. It bridges database engine metrics with modern AI clients (such as Claude Desktop, Cursor IDE, VS Code extensions, Antigravity, and LangChain/LlamaIndex frameworks).

```mermaid
graph TD
    subgraph "AI Client Layer"
        Claude[Claude Desktop]
        Cursor[Cursor IDE]
        VSCode[VS Code / Cline / Roo Code]
        Custom[Custom LLM Pipeline]
    end

    subgraph "MCP Server Layer (build/mcp_server.py)"
        JSONRPC[JSON-RPC 2.0 stdio Interface]
        Daemon[Background Audit Daemon]
        CacheManager[JSON / HTML Cache Store]
        RollbackEngine[Rollback & Transaction Engine]
    end

    subgraph "Database & Core Engine"
        PerlEngine[MySQLTuner Perl Core (mysqltuner.pl)]
        MySQLInstance[(MySQL / MariaDB / Percona Server)]
    end

    Claude <-->|stdio JSON-RPC| JSONRPC
    Cursor <-->|stdio JSON-RPC| JSONRPC
    VSCode <-->|stdio JSON-RPC| JSONRPC
    Custom <-->|stdio JSON-RPC| JSONRPC

    JSONRPC --> Daemon
    Daemon -->|Executes --agent-json| PerlEngine
    PerlEngine -->|SQL Telemetry| MySQLInstance
    PerlEngine -->|Structured JSON| CacheManager
    CacheManager -->|Resources & Findings| JSONRPC
    RollbackEngine -->|SET GLOBAL / Revert| MySQLInstance
```

---

## ⚡ Mode 1: Direct CLI Machine Integration (`--agent-json`)

When invoked with `--agent-json`, `mysqltuner.pl` suppresses ANSI formatting and outputs a clean, single-payload JSON schema designed for direct LLM ingestion or programmatic parsing.

### CLI Command Syntax
```bash
perl mysqltuner.pl --agent-json --host <db_host> --user <db_user> --pass <db_pass>
```

### JSON Schema & Field Specifications
```json
{
  "findings": [
    {
      "id": "innodb_buffer_pool_size_adjust",
      "topic": "Performance",
      "description": "InnoDB buffer pool size is under-allocated for current workload.",
      "impact_score": 9,
      "risk_level": "Medium",
      "risk_description": "Increases memory consumption. Ensure sufficient OS-free RAM to prevent OOM swapping.",
      "requires_restart": false,
      "expected_outcome": "Reduces disk I/O and increases query cache read hits.",
      "action": {
        "type": "SQL",
        "statement": "SET GLOBAL innodb_buffer_pool_size = 1073741824;",
        "rollback_statement": "SET GLOBAL innodb_buffer_pool_size = 134217728;"
      }
    }
  ]
}
```

#### Field Glossary:
- **`id`**: Deterministic key for the specific diagnostic check.
- **`topic`**: Domain (`Performance`, `Security`, `Reliability`, `Modeling`, `Replication`).
- **`impact_score`**: Estimated optimization value on a scale of `1` (minor) to `10` (critical optimization).
- **`risk_level`**: Safety classification (`Low`, `Medium`, `High`, `Critical`).
- **`risk_description`**: Detailed side-effect analysis (memory allocation, table lock potential, restart requirement).
- **`requires_restart`**: Boolean (`true`/`false`) indicating if `my.cnf` edit and service restart is required.
- **`action`**: Object containing the executable `statement` (`SQL` or `Config`) and its counterpart `rollback_statement`.

---

## 🔌 Mode 2: Model Context Protocol (MCP) Server Interface

The MySQLTuner MCP server ([build/mcp_server.py](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/build/mcp_server.py)) implements the standard MCP specification over `stdio` transport using JSON-RPC 2.0.

### Exposed MCP Resources

| URI Resource | Content Type | Description |
| :--- | :--- | :--- |
| `mysqltuner://reports/latest.json` | `application/json` | Accesses the latest cached audit findings and database variable state. |
| `mysqltuner://reports/latest.html` | `text/html` | Retrieves the interactive HTML analytics report (pgBadger-style visuals). |
| `mysqltuner://indicators/summary.json` | `application/json` | Provides high-level KPI indicators (Performance, Security, Resilience scores). |

### Exposed MCP Tools

#### 1. `get_latest_audit`
* **Purpose**: Retrieves cached audit findings instantly without querying the database server.
* **Arguments**: None.

#### 2. `run_audit`
* **Purpose**: Triggers a live execution of `mysqltuner.pl --agent-json` and updates the cache.
* **Arguments**: None.

#### 3. `apply_recommendation`
* **Purpose**: Applies a safe, dynamic SQL tuning adjustment (`SET GLOBAL`).
* **Arguments**:
  - `statement` (string, required): The SQL command to execute.
  - `variable_name` (string, optional): Target variable to capture pre-execution baseline for rollback.

#### 4. `rollback_recommendation`
* **Purpose**: Reverts a previously applied SQL modification using recorded transaction state.
* **Arguments**:
  - `statement_id` (string, required): Transaction identifier returned during `apply_recommendation`.

---

## 🚀 Deployment & Configuration Guide

### Containerized Deployment (Recommended Microservice)

The official Docker image ([Dockerfile.mcp](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/Dockerfile.mcp)) packages Perl, Python 3, mysql-client, and the MCP server.

```bash
docker run -d \
  --name mysqltuner-mcp \
  -e DB_HOST=mysql-server \
  -e DB_PORT=3306 \
  -e DB_USER=root \
  -e DB_PASSWORD=secret_pass \
  -e AUDIT_INTERVAL_HOURS=6 \
  -v /var/cache/mysqltuner:/var/cache/mysqltuner \
  mysqltuner-mcp
```

#### Supported Environment Variables:
- `DB_HOST`: Hostname or IP address of the target MySQL/MariaDB server (default: `127.0.0.1`).
- `DB_PORT`: Database port (default: `3306`).
- `DB_USER`: Database audit user (default: `root`).
- `DB_PASSWORD`: Password for the database user.
- `AUDIT_INTERVAL_HOURS`: Periodic audit refresh interval in hours (default: `6`).
- `CACHE_DIR`: Cache directory for report artifacts (default: `/var/cache/mysqltuner`).

---

### Client IDE & Agent Configurations

#### 1. Claude Desktop
Edit your Claude configuration file:
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
        "DB_PASSWORD=your_password",
        "mysqltuner-mcp"
      ]
    }
  }
}
```

#### 2. Cursor IDE
1. Go to **Settings** -> **Features** -> **MCP**.
2. Click **+ Add New MCP Server**.
3. Configure settings:
   - **Name**: `mysqltuner`
   - **Type**: `stdio`
   - **Command**: `python3 /path/to/MySQLTuner-perl/build/mcp_server.py`

#### 3. VS Code (Cline / Roo Code)
Add to `mcpSettings.json`:
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

## 🛡️ AI Agent Governance & System Prompt

To ensure safe, production-grade operations, inject the following system prompt into your LLM agent context:

```markdown
You are a Principal Database Administrator (DBA) managing a MySQL/MariaDB infrastructure via the MySQLTuner MCP server.

### Safety Rules:
1. **Baseline Inspection**: Always run `get_latest_audit` before proposing changes.
2. **Risk Categorization**:
   - `Low` / `Medium` risk statements with `requires_restart: false` can be applied live after presenting the rollback statement to the user.
   - `High` / `Critical` risk statements or changes with `requires_restart: true` MUST require explicit confirmation.
3. **Rollback Availability**: Always state both the `statement` and `rollback_statement` prior to executing `apply_recommendation`.
4. **Post-Execution Verification**: Call `run_audit` after executing changes to verify KPI score improvement. If metrics regress, immediately execute `rollback_recommendation`.
```
