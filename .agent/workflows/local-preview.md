---
description: Start a local PHP development server to preview the site.
---
# Local Preview Workflow

1. Start the PHP built-in server in the background:
// turbo

```bash
php -S localhost:8000 > /tmp/php_mt_site.log 2>&1 &
```

1. Wait for the server to initialize.

2. Provide the user with the preview link:
<http://localhost:8000>

3. To stop the server:
// turbo

```bash
pkill -f "php -S localhost:8000"
```

## ✅ Verification

- Use `read_url_content` or `browser_subagent` to confirm the server is responsive.
