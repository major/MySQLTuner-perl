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
- **Zero-Dependency Portability**: Maintain a single-file architecture. The script must remain self-contained and executable on any server with a base Perl installation.
- **Universal Compatibility**: Support the widest possible range of MySQL-compatible versions (Legacy 5.5 to Modern 11.x).
- **Regression Limit**: Proactively identify and prevent regressions through exhaustive automated testing.
- **Actionable Insights**: Provide clear, verified, and well-documented tuning advice.

## ✅ Verification

- All technical decisions must be cross-referenced with this document.
- Use `/compliance-sentinel` to audit deviations.
