# Issue #1003: AI Skill Specification — analyze_buffer_pool

**Type:** Feature / AI Skill  
**Component:** `build/mcp_server.py`, `.agent/skills/analyze-buffer-pool/SKILL.md`, `tests/unit_skill_buffer_pool.t`  
**Assignee:** jmrenouard  
**Labels:** `mcp`, `skill`, `innodb`, `performance`, `memory`  

## 🎯 Description & Objectives
Implement the specialized AI Diagnostic Skill `analyze_buffer_pool` in the MySQLTuner MCP server.
This skill allows LLM agents and autonomous DBA routines to deeply evaluate InnoDB Buffer Pool memory allocation, caching efficiency, dirty page ratios, and instance partitioning without needing manual log parsing.

### Diagnostic Algorithms
1. **Cache Efficiency (Hit Ratio)**:
   $$\text{Hit Ratio} = \left(1 - \frac{\text{Innodb\_buffer\_pool\_reads}}{\text{Innodb\_buffer\_pool\_read\_requests}}\right) \times 100$$
   - Target: $\ge 99.0\%$ for OLTP workloads.
2. **Page Utilization**:
   - $\text{Free Page Ratio} = \frac{\text{pages\_free}}{\text{pages\_total}} \times 100$
   - $\text{Dirty Page Ratio} = \frac{\text{pages\_dirty}}{\text{pages\_total}} \times 100$ (Alert threshold: $> 75\%$)
3. **Dataset vs Buffer Pool Sizing**:
   - Total InnoDB Data + Index footprint vs `innodb_buffer_pool_size`.
4. **Instance Concurrency**:
   - For buffer pools $> 1\text{GB}$, recommend `innodb_buffer_pool_instances` matching CPU cores (up to 64, typical 8).

## 🧪 Acceptance Criteria
- [x] Skill registered in MCP Tools Catalog as `analyze_buffer_pool` with strict JSON Schema.
- [x] Returns typed output with metrics, health status, and rollback-ready SQL recommendations.
- [x] Unit test `tests/unit_skill_buffer_pool.t` covering optimal, undersized, and dirty-stall states.
- [x] Documentation in `.agent/skills/analyze-buffer-pool/SKILL.md`.
