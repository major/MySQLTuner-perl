---
trigger: always_on
---

## **3\. 🏗️ TECHNICAL ENVIRONMENT & ARCHITECTURE**

$$IMMUTABLE$$  
Component Map:  
Modification prohibited without explicit request.  

| File/Folder | Functionality | Criticality |
| :--- | :--- | :--- |
| mysqltuner.pl | **Main script - SINGLE FILE ARCHITECTURE ENFORCED** | 🔴 CRITICAL |
| Makefile | Command orchestrator (Test, Build, Lint) | LOW |
| Dockerfile | Containerized execution environment | 🟡 MEDIUM |
| .agent/ | Agent-specific rules and workflows | LOW |
| documentation/ | Technical documentation and reports | 🟡 HIGH |
| tests/ | Test suite for validator and tuning logic | 🟡 HIGH |

**Technology Stack:**

* **Language:** Perl (Core script)
* **Testing:** Perl (prove, Test::More)
* **Automation:** Makefile, Bash, Docker, Python, Per
* **DBMS Compatibility:** MySQL, MariaDB, Percona, AWS, AWS Aurora, Docker, GCP, Azure
