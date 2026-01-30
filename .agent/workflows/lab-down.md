---
trigger: /lab-down
description: Stops and cleans up the database laboratory.
category: tool
---
# Lab Down

## 🧠 Rationale

Resources cleanup after debugging sessions.

## 🛠️ Implementation

// turbo

1. Stop the lab

```bash
make lab-down
```

## ✅ Verification

- Validate with `docker ps` that no containers are running.
