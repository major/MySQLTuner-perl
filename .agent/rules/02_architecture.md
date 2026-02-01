---
trigger: always_on
description: Technical environment and architecture map.
category: governance
---
# **2. 🏗️ TECHNICAL ENVIRONMENT & ARCHITECTURE**

## 🧠 Rationale

Preserving the lightweight PHP architecture ensures maximum portability and speed.

## 🛠️ Implementation

$$IMMUTABLE$$

| File/Folder | Functionality | Criticality |
| :--- | :--- | :--- |
| index.php | Main router and entry point | 🔴 CRITICAL |
| includes/ | Core layouts (header, footer, sidebar) | 🔴 CRITICAL |
| public/docs/ | Markdown documentation sources | 🔴 CRITICAL |
| assets/css/ | Global styling and design system | 🟡 HIGH |
| scripts/ | Automation scripts (sync_docs.py) | 🟡 HIGH |

**Technology Stack:**

- **Language**: PHP (Server-side rendering)
- **Engine**: Parsedown (Markdown processing)
- **Styling**: Vanilla CSS (Modern technical aesthetic)
- **Typography**: Inter & Outfit (Google Fonts)
- **Icons**: Emoji & Custom SVG

## ✅ Verification

- Ensure any new library is single-file and PHP-based.
