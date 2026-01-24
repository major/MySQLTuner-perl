---
trigger: always_on
---

If new rules are invoked with the `REMEMBER:` tag in a conversation, trigger the `/remember` workflow.
Update this file following the steps defined in `.agent/workflows/remember.md`.

REMEMBER:
Rule: Don't forget to updates this file with REMEMBER: tag
Rule: Documentation updates (`docs:`) following Conventional Commits can skip manual `@Changelog` entry if they are synchronization-only.
Rule: New tests MUST have a `test:` entry in the `@Changelog`.
Rule: Test script or infrastructure updates MUST have a `ci:` entry in the `@Changelog`.
