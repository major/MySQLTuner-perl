---
trigger: /lab-up
description: Starts a persistent database laboratory and injects data.
category: tool
---
# Lab Up

## 🧠 Rationale

Speeds up iterative debugging by keeping containers running.

## 🛠️ Implementation

// turbo

1. Start the lab for a specific configuration (e.g., CONFIGS="mysql84")

```bash
make lab-up CONFIGS="${CONFIGS:-mysql84}"
```

1. Run MySQLTuner directly against the lab

```bash
perl mysqltuner.pl --host 127.0.0.1 --user root --pass mysqltuner_test
```

## ✅ Verification

- Validate with `docker ps` that the container is running.
