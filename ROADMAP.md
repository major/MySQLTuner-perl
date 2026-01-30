# MySQLTuner-perl Roadmap

This document outlines the strategic direction and future development plans for MySQLTuner-perl. Our mission is to provide the most stable, portable, and reliable performance tuning advisor for MySQL-compatible databases.

## 👤 Governance

To ensure consistency and high-density development, the following roles are defined for roadmap orchestration:

* **Owner**: [Jean-Marie Renouard](https://github.com/jmrenouard) (@jmrenouard) - Ultimate authority on the project, constitution, and core mission.
* **Product Manager**: **Antigravity (AI Agent)** - Responsible for backlog management, specification design, and execution tracking of the roadmap items.
* **Release Manager**: **Antigravity (AI Agent)** - Responsible for technical validation, testing orchestration, and unified release cycle execution.

## 🌟 Strategic Pillars

1. **Production Stability & Safety**: All recommendations must be verified and safe for production.
2. **SQL Modeling & Schema Design**: Beyond operational tuning, provide deep insights into database architecture.
3. **Zero-Dependency Portability**: Maintain single-file architecture with core-only dependencies.
4. **Modern Ecosystem Support**: Seamless integration with Containers (Docker/K8s) and Cloud providers.

---

## 🚀 Development Phases

### Phase 1: Stabilization & Observability (v2.8.32)

* **Metadata-Driven CLI Options**: Refactor option parsing to centralize defaults, validation, and documentation. This eliminates synchronization errors between code and POD.
* **Enhanced SQL Modeling**: Expand diagnostic checks for:
  * Foreign Key type mismatches (e.g., `INT` vs `BIGINT`).
  * Missing indexes on large tables (> 1GB).
  * Schema sanitization (detection of empty or view-only schemas).
* **Structured Error Log Ingestion**: Support `performance_schema.error_log` for diagnostic ingestion (MySQL 8.0+).
* **Refined Reporting**: Improve the data richness in the new "Modeling Analysis" tab.

### Phase 2: Advanced Diagnostics

* **Index Audit 2.0**: Integrate `performance_schema` to detect:
  * **Redundant Indexes**: Overlapping prefix indexes that waste storage and IO.
  * **Unused Indexes**: Identify indexes that haven't been touched since last restart.
* **Transactional Contention Analysis**: Detect patterns leading to deadlocks and high lock wait times.
* **Buffer Pool Advisory**: More granular analysis of InnoDB Buffer Pool usage and resizing recommendations.
* **Aria & MyISAM Modernization**: Deeper checks for Aria-specific parameters (`aria_pagecache_age_threshold`) and migration paths for legacy engines.
* **Kernel & Architecture Health**: Implement `io_uring` support detection, verifying kernel settings (`kernel.io_uring_disabled`) and group permissions.

### Phase 3: Automation & Ecosystem

* **Modular Reporting Engine**: Refactor Jinja2 templates to support dynamic section injection, allowing for highly extensible HTML reports.
* **Container Abstraction Layer**: Refine transport discovery logic to handle complex K8s/Docker network topologies and permission constraints.
* **Historical Trend Analysis**: (Experimental) Allow the script to ingest previous run data to identify performance regressions over time.

## 🤝 Contribution & Feedback

We welcome community feedback on this roadmap. If you have specific feature requests or want to contribute to a specific phase, please open an issue on our [GitHub repository](https://github.com/jmrenouard/MySQLTuner-perl).
