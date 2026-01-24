---
description: Formalize and record new project rules and best practices.
---

# Remember Workflow

This workflow is used to capture and implement new rules, best practices, or constraints identified during pair programming.

## Trigger

- When the user explicitly requests to "remember" a new rule or pattern using the `REMEMBER:` tag.
- When the agent identifies a recurring problem that requires a systematic fix in the constitution.

## Steps

1. **Identify the Rule**: Extract the core principle or instruction from the conversation.
2. **Update Autolearning**: Add the rule to `.agent/rules/autolearning.md` under the `REMEMBER` section.
   - Use the format: `Rule: [Rule description]`
3. **Synchronize Main Rules**: If the rule is a core constraint, update `.agent/rules/03_execution_rules.md` or other relevant specification files.
4. **Validation**: Confirm the update with the user via `notify_user`.

## Context Maintenance

- The `.agent/rules/autolearning.md` file serves as the long-term memory for these dynamically acquired rules.
- Always check this file at the start of a session (it is `always_on`).
