# Specification: Roadmap Phase XVII - Dockerized Auditing Daemon & MCP Server Support

- **Feature Name**: Dockerized Auditing Daemon & MCP Server Support
- **Status**: Draft
- **Created Date**: 2026-06-25

## 🧠 Rationale

AI agents interact with tools and local resources using the **Model Context Protocol (MCP)**. To allow modern LLM coding and platform agents to easily query, inspect, and perform safe self-tuning operations on database servers, MySQLTuner needs to be deployable as an autonomous microservice.

This phase specifies:
1. **Dockerized Auditing Daemon**: A lightweight Docker image running as a background service that queries the target database at configurable intervals, performs checks, and caches findings.
2. **MCP Server Interface**: Exposing MySQLTuner findings and safe execution statements through standard MCP Tools and Resources.
3. **Caching and Query Layer**: Storing recent runs locally in a cache database/directory to avoid overloading the production database with repeated audits.

## 🛠️ User Scenarios

### Scenario 1: Continuous Observability Daemon
A system administrator deploys the MySQLTuner Docker image alongside their database container in a Docker Compose file. The daemon is configured to run an audit every 12 hours. It caches the structured JSON and HTML reports in a shared volume.

### Scenario 2: LLM-Driven Database Tuning via MCP
An AI coding assistant (like Antigravity or Cursor) is asked to optimize database performance. The agent connects to the MySQLTuner MCP server, invokes the `get_latest_audit` tool to inspect the cached findings, identifies indexing recommendations, and invokes the `apply_recommendation` tool to run the safe SQL optimization.

## 📋 Technical Architecture

### 1. Docker Auditing Daemon
The Docker container will run a lightweight daemon script (written in Perl or Python) acting as an orchestrator:
- **Environment Variables**:
  - `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD` (or socket mounts).
  - `AUDIT_INTERVAL_HOURS`: Run audit every X hours (default: `12`).
  - `CACHE_DIR`: Location to persist JSON/HTML reports (default: `/var/cache/mysqltuner`).
- **Interval Auditor**: Sleep/loop execution with SIGTERM/SIGINT signal handling for graceful termination.

### 2. MCP Server Protocol Support
The MCP server protocol will be implemented over standard I/O (stdio) transport or SSE (Server-Sent Events) HTTP transport. It exposes:

#### Resources
- `resources/list`:
  - `mysqltuner://reports/latest.json`: The latest structured agent JSON.
  - `mysqltuner://reports/latest.html`: The latest interactive HTML dashboard.
- `resources/read`: Retrieves the raw content of the cached latest JSON/HTML.

#### Tools
- `get_latest_audit`:
  - Input: None.
  - Output: The JSON structure containing current recommendations.
- `run_audit`:
  - Input: None.
  - Output: Triggers a fresh run of MySQLTuner and returns the latest findings.
- `apply_recommendation`:
  - Input: `finding_id` (the ID of the recommendation to execute).
  - Behavior: Verifies that the recommendation type is `SQL`, checks that risk is acceptable, and runs the corresponding `statement` against the database.
  - Output: Success/Failure status and output logs.
- `rollback_recommendation`:
  - Input: `finding_id`.
  - Behavior: Runs the corresponding `rollback_statement` to revert changes.

## ⚠️ Risk & Safety Mitigation

Tuning operations on production databases pose high risk. The MCP server implements:
1. **Execution Restriction**: Only `SQL` actions of `risk_level` `Low` or `Medium` can be executed automatically. `Critical` risk items require manual override.
2. **Read-Only Mode**: A boot flag `READ_ONLY=true` can be set to disable the write tools (`apply_recommendation`, `rollback_recommendation`), making the MCP server a pure observability tool.
3. **Transaction Logging**: Every applied action and rollback is logged in a state file (`/var/cache/mysqltuner/state.json`) with timestamps.

## ✅ Verification Plan

### Manual Verification
1. Build the Docker image: `docker build -t mysqltuner-mcp -f Dockerfile.mcp .`.
2. Run container: `docker run -d -e DB_HOST=localhost -e AUDIT_INTERVAL_HOURS=2 -v /tmp/cache:/var/cache/mysqltuner mysqltuner-mcp`.
3. Verify that `/tmp/cache/latest.json` is generated and updated every 2 hours.
4. Interact with the running container using an MCP client CLI (e.g. `@modelcontextprotocol/inspector`) and verify tools and resources are correctly exposed.
