---
description: Automated audit to enforce project constitution rules
---

# Compliance Sentinel

This workflow acts as a static analysis guardrail to ensure "Constitution" compliance.

## 1. Core Check: Single File Architecture

Ensure no additional Perl modules (.pm) have been added to the root or lib dirs intended for distribution.

```bash
if [ $(find . -maxdepth 2 -name "*.pm" | wc -l) -gt 0 ]; then
  echo "FAIL: No .pm files allowed. Architecture must remain Single File."
  exit 1
fi
```

## 2. Core Check: Zero Dependency (Standard Core Only)

Scan for non-core CPAN modules.

```bash
# Allow-list (examples of standard modules)
# strict, warnings, Getopt::Long, File::Basename, Data::Dumper, POSIX, etc.
# Grep for 'use' and manually review or verify against `corelist`.
grep "^use " mysqltuner.pl | sort | uniq
```

## 3. Core Check: Syscall Protection

Verify that system calls are safe.

```bash
# Look for potential unsafe system calls (qx, ``, system)
grep -nE "qx/|`|system\(" mysqltuner.pl
# Manual Review: Ensure each is wrapped or checked.
```

## 4. Changelog Compliance

Verify the format of the latest Changelog entries.

```bash
head -n 20 Changelog
# Must follow:
# X.Y.Z YYYY-MM-DD
# - type: description
```

## 5. Execution

Run these checks before any major commit or release.
