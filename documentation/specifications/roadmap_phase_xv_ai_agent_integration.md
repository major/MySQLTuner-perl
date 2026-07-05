# Specification: Roadmap Phase XVI - AI Agent Integration & Actionable JSON Schema

- **Feature Name**: AI Agent Integration & Actionable JSON Schema
- **Status**: Draft
- **Created Date**: 2026-06-25

## 🧠 Rationale

As database operations become increasingly automated by AI agents (e.g., MCP-based workflows, specialized IDE agents, autonomous DBAs), standard human-readable terminal output and even simple YAML/JSON key-value exports are insufficient.

To safely enable an AI agent to act on database advisor findings, the agent needs:
1. **Machine-Ingestible Action Schema**: Structured recommendations that specify the exact SQL statements (DDL/DML) or configuration adjustments required.
2. **Deterministic Rollback Action**: The precise inverse command to undo the action in case of performance regressions or unexpected failure.
3. **Safety & Risk Categorization**: An explicit risk assessment (e.g., whether a table lock is required, if a restart is needed) and an impact score/topic.
4. **Expected Outcomes**: Declarative descriptions of what the change will improve (e.g., memory usage reduction, cache hit rate increase).

This phase adds a robust `--agent-json` output flag to `mysqltuner.pl` that outputs a highly structured, machine-actionable JSON payload.

## 🛠️ User Scenarios

### Scenario 1: Autonomous Tuning Agent
An AI agent connects to a database via an MCP server, runs MySQLTuner with `--agent-json`, parses the recommendations, and automatically applies P1 (high impact, low risk) recommendations using the provided `sql_statement`.

### Scenario 2: Human-in-the-Loop Safe Rollback
An AI agent proposes a schema optimization (e.g. dropping a redundant index). It shows the user the description, expected outcome, and the provided `rollback_statement`. If the user consents, the agent executes the change. If a regression occurs later, the agent executes the `rollback_statement` to revert to the baseline.

## 📋 JSON Schema Specification

The `--agent-json` format will output a JSON object containing a `findings` list. Each finding conforms to the following schema:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "AgentFinding",
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "description": "Unique deterministic identifier for the recommendation type."
    },
    "topic": {
      "type": "string",
      "enum": ["Performance", "Security", "Reliability", "Modeling", "Replication"],
      "description": "The category of the finding."
    },
    "description": {
      "type": "string",
      "description": "Human-readable explanation of the issue."
    },
    "impact_score": {
      "type": "integer",
      "minimum": 1,
      "maximum": 10,
      "description": "Estimated benefit score from 1 (low) to 10 (critical)."
    },
    "risk_level": {
      "type": "string",
      "enum": ["Low", "Medium", "High", "Critical"],
      "description": "Risk associated with executing the recommendation."
    },
    "risk_description": {
      "type": "string",
      "description": "Details of potential side effects (e.g. table locks, memory growth, restart required)."
    },
    "requires_restart": {
      "type": "boolean",
      "description": "True if the configuration change requires a database service restart."
    },
    "expected_outcome": {
      "type": "string",
      "description": "The expected performance or security benefit."
    },
    "action": {
      "type": "object",
      "properties": {
        "type": {
          "type": "string",
          "enum": ["SQL", "Config", "OS"],
          "description": "Type of resolution action."
        },
        "statement": {
          "type": "string",
          "description": "The exact SQL statement, configuration line, or shell command to execute."
        },
        "rollback_statement": {
          "type": "string",
          "description": "The exact command to revert the action to its original state."
        }
      },
      "required": ["type", "statement", "rollback_statement"]
    }
  },
  "required": [
    "id",
    "topic",
    "description",
    "impact_score",
    "risk_level",
    "risk_description",
    "requires_restart",
    "expected_outcome",
    "action"
  ]
}
```

### Finding Example
```json
{
  "id": "innodb_buffer_pool_size_adjust",
  "topic": "Performance",
  "description": "InnoDB buffer pool size is under-allocated for the current workload.",
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
```

## ✅ Verification Plan

### Automated Tests
1. Test generation of `--agent-json` output and validate its conformance to the schema.
2. Validate that each generated recommendation has a corresponding valid `rollback_statement`.
3. Verify that parsing of database metrics properly populates all metadata fields (e.g., `impact_score`, `risk_level`, `requires_restart`).
