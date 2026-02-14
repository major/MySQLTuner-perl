# Specification: Compliance Sentinel - Remembers Integration

## Goal

Ensure the `compliance-sentinel` workflow validates against dynamic project rules defined in `remembers.md`.

## Integration Points

### 1. Dynamic Rule Validation

The `compliance-sentinel` must include a section dedicated to "Session-Level & Dynamic Rules".

### 2. Automated Checks

- **Audit Logs**: Execute `perl build/audit_logs.pl --dir=examples` (or similar).
- **Potential Issues Accountability**: Verify that `POTENTIAL_ISSUES` file exists and is not empty if the audit script finds anomalies.
- **Rule Synchronization**: Ensure any rule in `remembers.md` tagged as "STRICT" or "MANDATORY" (implicitly all rules in that file) are manually verifiable or automatically checked.

## Verification

- Running `compliance-sentinel` should fail if `audit_logs.pl` finds unacknowledged critical anomalies.
