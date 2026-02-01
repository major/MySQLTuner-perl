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

### Phase 1: Stabilization & Observability (v2.8.31 - v2.8.33) [COMPLETED]

* [x] **Metadata-Driven CLI Options**: Refactored option parsing to centralize defaults, validation, and documentation.
* [x] **Enhanced SQL Modeling**: Expanded diagnostic checks for Foreign Key type mismatches, missing indexes, and schema sanitization.
* [x] **Structured Error Log Ingestion**: Supported `performance_schema.error_log` for diagnostic ingestion (MySQL 8.0+).
* [x] **Refined Reporting**: Improved data richness in the "Modeling Analysis" tab.

### Phase 2: Advanced Diagnostics [IN PROGRESS]

* **Plugin & Hook Stability**: Formalize the custom hook mechanism (verified for MySQL and SSL) to enable scalable third-party integrations.
* **Compliance Awareness Framework**: Specialized audit profiles (`--audit-pci`, `--audit-hipaa`, `--audit-gdpr`) to verify regulatory configuration requirements.
* **Index Audit 2.0**: Integrate `performance_schema` to detect redundant and unused indexes.
* **Transactional Contention Analysis**: Detect patterns leading to deadlocks and high lock wait times.
* **Buffer Pool Advisory**: More granular analysis of InnoDB Buffer Pool usage and resizing recommendations.
* **Kernel & Architecture Health**: Implement `io_uring` support detection and kernel setting verification.

### Phase 3: Automation & Ecosystem

* **Infrastructure-Aware Tuning**: Detect storage types (NVMe/SSD) and hardware architectures (ARM64/Graviton).
* **Sysbench Metrics Integration**: Automated baseline capture and performance comparison within the report.
* **Multi-Cloud Autodiscovery**: Automated detection of RDS, GCP, and Azure specific performance flags and optimizations.
* **Query Anti-Pattern Detection**: Use `performance_schema` to identify non-SARGable queries and `SELECT *` abuse.
* **Modular Reporting Engine**: Refactor Jinja2 templates for dynamic section injection.
* **Historical Trend Analysis**: (Experimental) Allow the script to ingest previous run data to identify performance regressions.

### Phase 4: Advanced Intelligence & Ecosystem

* **Smart Migration LTS Advisor**: Provide risk reports for upgrading between major versions.
* **Weighted Health Score**: Implement a unified KPI (0-100) based on Security, Performance, and Resilience.

## 🤝 Contribution & Feedback

We welcome community feedback on this roadmap. If you have specific feature requests or want to contribute to a specific phase, please open an issue on our [GitHub repository](https://github.com/jmrenouard/MySQLTuner-perl).
