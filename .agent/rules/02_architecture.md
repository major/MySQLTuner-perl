---
trigger: always_on
description: Immutable project architecture and technology stack.
category: governance
---
# **3\. 🏗️ TECHNICAL ENVIRONMENT & ARCHITECTURE**

## 🧠 Rationale

Preserving the single-file architecture of `mysqltuner.pl` is a core technical constraint that ensures maximum portability and ease of deployment.

## 🛠️ Implementation

$$IMMUTABLE$$  
Component Map:  

| File/Folder | Functionality | Criticality |
| :--- | :--- | :--- |
| mysqltuner.pl | **Main script - SINGLE FILE ARCHITECTURE ENFORCED** | 🔴 CRITICAL |
| Makefile | Command orchestrator (Test, Build, Lint) | LOW |
| Dockerfile | Containerized execution environment | 🟡 MEDIUM |
| .agent/ | Agent-specific rules and workflows | LOW |
| documentation/ | Technical documentation and reports | 🟡 HIGH |
| tests/ | Test suite for validator and tuning logic | 🟡 HIGH |

**Technology Stack:**

- **Language:** Perl (Core script)
- **Testing:** Perl (prove, Test::More)
- **Automation:** Makefile, Bash, Docker, Python
- **DBMS Compatibility:** MySQL, MariaDB, Percona, AWS, AWS Aurora, GCP, Azure

## ✅ Verification

- `/compliance-sentinel` must fail if `mysqltuner.pl` is split or if non-core dependencies are added.
- All builds must pass via `make docker_build`.
