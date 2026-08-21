---
name: detect_fragmented_tables
description: Detects tables with high storage fragmentation, calculates reclaimable disk space, evaluates lock impact, and generates safe defragmentation commands.
---

# AI Skill: Table Fragmentation & Storage Reclaim Diagnostics

## 🧠 Purpose & Operational Objectives
The `detect_fragmented_tables` skill enables autonomous DBA agents to identify wasted disk space, high data file fragmentation, and unused allocated extents across InnoDB and MyISAM tables.

## 📋 Preconditions & Context
- Server running MySQL 5.5+ or MariaDB 10.0+.
- Read access to `information_schema.TABLES`.
- Evaluates non-system schemas (skips `mysql`, `information_schema`, `performance_schema`, `sys`).

## 🛠️ Input Parameters
| Parameter | Type | Required | Default | Description |
|:---|:---|:---|:---|:---|
| `min_fragmentation_pct` | number | No | `20` | Minimum fragmentation percentage (0-100) to trigger reporting. |
| `min_table_size_mb` | number | No | `10` | Minimum table size in MB to filter out trivial tables. |
| `schema_filter` | string | No | `""` | Optional schema name to restrict the scan. |

## 📊 Fragmentation Formula & Impact Scoring
$$\text{Total Allocated Space} = \text{DATA\_LENGTH} + \text{INDEX\_LENGTH} + \text{DATA\_FREE}$$
$$\text{Fragmentation Pct} = \left(\frac{\text{DATA\_FREE}}{\text{Total Allocated Space}}\right) \times 100$$

- **Tables $< 5\text{GB}$**: Can be defragmented online during low-traffic windows via `OPTIMIZE TABLE \`db\`.\`table\`;`.
- **Tables $\ge 5\text{GB}$**: Flagged as `is_high_impact: true`. Advise using online tools like `pt-online-schema-change` or `gh-ost` to prevent extended table locks and disk thrashing.

## 🛡️ Guardrails & Safety
- All schema and table names are safely escaped with backticks to prevent SQL injection.
- Reclaimable disk space is calculated deterministically.
