# 🧪 Run Unit & Regression Tests

This workflow provides a high-level orchestrator for executing tests, based on the industrial-grade knowledge encapsulated in the **Testing Orchestration Skill**.

## 🧠 Rationale

Consistency in testing is paramount. By offloading detailed knowledge to a dedicated skill, we ensure all developers and agents follow the same verified testing patterns.

## 🛠️ Implementation

### 1. Trigger Core Suite

Refer to the [Testing Orchestration Skill](file:///.agent/skills/testing-orchestration/SKILL.md) for detailed mandates (Tripartite Testing, Infrastructure Logs).

// turbo

```bash
# Execute standard unit test suite
prove -r tests/
```

### 2. Alternative Entry Points

- **CI/CD Logic**: `make unit-tests`
- **Multi-Version Lab**: `make test-it`

## ✅ Verification

Ensure the command returns an exit code of 0. Review any failures using `prove -v`.
