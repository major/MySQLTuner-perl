---
trigger: always_on
description: Best practices for MT-site development and aesthetics.
category: governance
---
# **4. 🌟 CORE BEST PRACTICES**

## 🧠 Rationale

Consistent high standards ensure the site remains premium and maintainable.

## 🛠️ Implementation

### 1. Visual "Aesthetic" Audit

- Use the **Browser Agent** to check:
  - Contrast ratios.
  - Hover animations.
  - Responsive layout (Mobile/Desktop).
  - Loading states (no white flashes).

### 2. Micro-Animations

- Apply `transition: all 0.3s ease;` to interactive elements.
- Use `opacity` and `transform: translateY` for entrance animations.

### 3. SEO & Accessibility

- Every page must have a unique `<title>` and `meta description`.
- Semantic HTML (`<main>`, `<article>`, `<nav>`) is mandatory.

### 4. Performance

- Optimize images (WebP preferred).
- Minimal external requests (Google Fonts are the exception).
- CSS should be under 50KB.

## ✅ Verification

- Use `visual-audit` skill for automated compliance checks.
