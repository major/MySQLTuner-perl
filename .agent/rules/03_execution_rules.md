---
trigger: always_on
description: Execution rules and constraints for MT-site.
category: governance
---
# **3. ⚙️ EXECUTION RULES & CONSTRAINTS**

## **3.1. Formal Prohibitions**

1. **NO FRAMEWORKS**: Use of heavy JS frameworks (React/Vue) is prohibited. Stick to PHP + Vanilla JS.
2. **ZERO DEPENDENCY**: No NPM/Node.js dependencies in production.
3. **PORTABILITY FIRST**: All paths must be relative or dynamically determined to work across different hostings.
4. **NO CONTENT DELETION**: Documentation content should only be updated or archived, never deleted without cause.

## **3.2. Aesthetic Guidelines**

1. **DARK MODE ONLY**: The site is primary dark-mode. High contrast but easy on the eyes.
2. **GLASSMORPHISM**: Use subtle background blurs and borders for overlays and headers.
3. **TYPOGRAPHY**: Titles in `Outfit`, body in `Inter`.
4. **ANIMATIONS**: Use CSS transitions for page loads and hover states (`fade-in`, `slide-up`).

## **3.3. Development Workflow**

1. **TDD (Visual)**: Before finalizing a UI change, verify it via `/local-preview`.
2. **SYNC CHECK**: After updating documentation, ensure the sync script is functional.
