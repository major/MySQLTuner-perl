---
trigger: explicit_call
description: Maintain only the 10 most recent results in the examples directory
category: tool
---

1. Execute the cleanup logic from the build script:
// turbo

```bash
bash build/test_envs.sh --cleanup
```

1. Verify that the `examples/` directory count is reduced to 10.
