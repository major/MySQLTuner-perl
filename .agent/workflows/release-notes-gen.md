---
trigger: explicit_call
description: Generate detailed technical release notes for the current version
category: tool
---

# Release Notes Generation Workflow

1. Run the release notes generator script for the current version:
// turbo

```bash
python3 build/release_gen.py
```

1. For bulk historical generation (e.g. since 2.8.0):
// turbo

```bash
python3 build/release_gen.py --since 2.8.0
```

1. Review the generated files in the `releases/` directory.
