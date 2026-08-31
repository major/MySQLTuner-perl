---
name: analyze_buffer_pool
description: Deeply analyzes InnoDB Buffer Pool efficiency, hit ratio, memory allocation, and instance concurrency to recommend optimal sizing.
---

# AI Skill: InnoDB Buffer Pool Sizing & Efficiency Analysis

## 🧠 Purpose & Operational Objectives
The `analyze_buffer_pool` skill enables autonomous DBA agents to diagnose memory pressure, caching efficiency, and dirty page write stalls in the InnoDB storage engine.

## 📋 Preconditions & Context
- Server running MySQL 5.5+ or MariaDB 10.0+ with InnoDB enabled.
- Database connectivity established or cached audit state available.
- Read-only execution: does not execute any modifying statements directly.

## 🛠️ Input Parameters
| Parameter | Type | Required | Default | Description |
|:---|:---|:---|:---|:---|
| `target_ram_percentage` | number | No | `75` | Target percentage of available host RAM dedicated to InnoDB (50-85%). |
| `include_dirty_pages` | boolean | No | `true` | Include dirty page write stall analysis. |

## 📊 Evaluation Criteria & Thresholds
1. **Hit Ratio**: $\frac{\text{read\_requests} - \text{reads}}{\text{read\_requests}} \times 100$
   - $\ge 99\%$: **OPTIMAL**
   - $95\% - 99\%$: **ACCEPTABLE**
   - $< 95\%$: **UNDERSIZED** (Generates disk I/O bottleneck)
2. **Dirty Page Ratio**: $\frac{\text{pages\_dirty}}{\text{pages\_total}} \times 100$
   - $> 75\%$: **DIRTY_STALL** (Risk of checkpoint flushing stalls)
3. **Instance Partitioning**:
   - For buffer pools $> 1\text{GB}$, recommend `innodb_buffer_pool_instances` $\ge 8$.

## 🛡️ Guardrails & Safety
- All recommendations specify exact SQL (`SET GLOBAL ...`) and rollback SQL.
- Changes requiring restart (e.g. `innodb_buffer_pool_instances` on older MySQL) are explicitly flagged with `requires_restart: true`.
