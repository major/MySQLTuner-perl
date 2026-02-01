---
trigger: explicit_call
description: Use the browser agent to audit the site's aesthetics.
category: skill
---
# Skill: Visual Audit

## 🧠 Rationale

Ensures the site meets the visual standards defined in the project constitution.

## 🛠️ Implementation

1. **Initialize Preview**: Run `/local-preview` to ensure the site is running.
2. **Browser Audit**: Open `http://localhost:8080` using the `browser_subagent`.
3. **Checks**:
   - Verify dark mode color palette (e.g., `#0f172a` background).
   - Check for glassmorphism effects (backdrop-filter).
   - Verify font loading (Inter/Outfit).
   - Check responsive behavior.
4. **Report**: Summarize findings and suggest improvements if "WOW" factor is missing.

## ✅ Verification

- Compare visual results with `specification.md` design goals.
