---
trigger: explicit_call
description: Check markdown content for cleanliness and project standard compliance (AFF, keywords, links)
category: tool
---

1. Execute the markdown linting script:
// turbo

```bash
python3 build/md_lint.py --all
```

1. Review the audit results and fix any identified issues (broken links, forbidden keywords, or missing AFF metadata).
