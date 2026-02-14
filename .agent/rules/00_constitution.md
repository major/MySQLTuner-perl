---
trigger: always_on
description: Core mission and unique source of truth for the project.
category: governance
---

# **AI CONTEXT SPECIFICATIONS & PROJECT CONSTITUTION**

## 🧠 Rationale

Establishing an absolute source of truth is critical for maintaining consistency and quality in an agentic coding environment. This constitution ensures all interventions align with the project's high-level goals.

## 🛠️ Implementation

$$SYSTEM\_CRITICAL$$  
Notice to the Agent: This document constitutes the unique and absolute source of truth for the project. Its prior consultation is imperative before any technical intervention.

**Core Mission:**
Make `mysqltuner.pl` the most stable, portable, and reliable performance tuning advisor for MySQL, MariaDB, and Percona Server.

**Key Pillars:**

- **Production Stability**: Every recommendation must be safe for production environments. Zero tolerance for destructive or experimental "hacks" without explicit user opt-in.
- **Single-File Architecture**: Strict enforcement of a single-file structure. Modules or splitting are prohibited to ensure maximum portability.
- **Zero-Dependency Portability**: The script must remain self-contained and executable on any server with a base Perl installation (Core modules only).
- **Universal Compatibility**: Support the widest possible range of MySQL-compatible versions (Legacy 5.5 to Modern 11.x).
- **Regression Limit**: Proactively identify and prevent regressions through exhaustive automated testing.
- **Actionable Insights**: Provide clear, verified, and well-documented tuning advice.
- **Release Integrity**: Guarantee artifact consistency and multi-version validation through a formal Release Management protocol.

## 🏗️ Governance Hierarchy (7-Tier AFF)

This project follows a standardized governance structure:

- **Tier 00**: [00_constitution.md](file:///.agent/rules/00_constitution.md) (Absolute Truth)
- **Tier 01**: [01_objective.md](file:///.agent/rules/01_objective.md) (Identity & Mission)
- **Tier 02**: [02_architecture.md](file:///.agent/rules/02_architecture.md) (Environment)
- **Tier 03**: [03_execution_rules.md](file:///.agent/rules/03_execution_rules.md) (Constraints)
- **Tier 04**: [04_best_practices.md](file:///.agent/rules/04_best_practices.md) (Implementation)
- **Tier 05**: [05_memory_protocol.md](file:///.agent/rules/05_memory_protocol.md) (History)
- **Dynamic**: [remembers.md](file:///.agent/rules/remembers.md) (Session Buffer)

## ✅ Verification

- All technical decisions must be cross-referenced with this document.
- Use `/compliance-sentinel` to audit deviations.
