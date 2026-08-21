# Issue #1007: AI Skill Specification — detect_fragmented_tables

**Type:** Feature / AI Skill  
**Component:** `build/mcp_server.py`, `.agent/skills/detect-fragmented-tables/SKILL.md`, `tests/unit_skill_fragmentation.t`  
**Assignee:** jmrenouard  
**Labels:** `mcp`, `skill`, `storage`, `tables`, `defragmentation`  

## 🎯 Description & Objectives
Implement the specialized AI Diagnostic Skill `detect_fragmented_tables` in the MySQLTuner MCP server.
This skill allows LLM agents and DBA tools to scan user tables, compute unused allocated pages (`Data_free`), estimate reclaimable storage, assess online defragmentation locks, and propose safe optimization scripts.

### Diagnostic Algorithms
1. **Scope Filtering**:
   - Excludes system databases: `information_schema`, `mysql`, `performance_schema`, `sys`.
   - Filters tables below `min_table_size_mb` (default: 10MB) to ignore transient or small datasets.
2. **Fragmentation Calculation**:
   $$\text{Total Space} = \text{DATA\_LENGTH} + \text{INDEX\_LENGTH} + \text{DATA\_FREE}$$
   $$\text{Fragmentation Pct} = \left(\frac{\text{DATA\_FREE}}{\text{Total Space}}\right) \times 100$$
3. **Lock & Impact Assessment**:
   - Tables $< 5\text{GB}$: Recommend direct `OPTIMIZE TABLE \`db\`.\`tbl\`;` (InnoDB online rebuild).
   - Tables $\ge 5\text{GB}$: Flag `is_high_impact: true` and advise off-peak scheduling or online schema change tools (`pt-online-schema-change`, `gh-ost`).

## 🧪 Acceptance Criteria
- [x] Registered in MCP Tools Catalog as `detect_fragmented_tables` with strict JSON Schema.
- [x] Computes cumulative reclaimable storage in human-readable and raw byte formats.
- [x] Unit test `tests/unit_skill_fragmentation.t` verifying filtering, fragmentation ratios, and high-impact classification.
- [x] Documentation in `.agent/skills/detect-fragmented-tables/SKILL.md`.
