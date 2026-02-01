# Specification: MySQLTuner Full Documentation Website

## 1. Overview

Transform `MT-site` into a comprehensive documentation hub. The site will transition from a single landing page to a multi-section knowledge base while maintaining the premium dark-mode aesthetic.

## 2. Information Architecture

### 2.1. Home Page (Existing)

- High-impact landing page (Hero, terminal mockup, value props).

### 2.2. Documentation Hub (New)

- **Sidebar**: Sticky navigation with hierarchical grouping.
- **Search**: Client-side full-text search (Fuse.js).
- **Sections**:
  - **Getting Started**: Installation, quick start, common options.
  - **Technical Internals**: Detailed breakdown of `INTERNALS.md` (Steps, Checks, System calls).
  - **Usage Guide**: Comprehensive flag reference from `USAGE.md`.
  - **Support Matrix**: Visual tables for MySQL/MariaDB version compatibility.

### 2.3. Release Notes Archive

- List of all releases from `releases/*.md`.
- Grouped by major version.
- Permalink for each release.

### 2.4. FAQ & Troubleshooting

- Dedicated page for FAQ (extracted from `README.md` and repo history).
- Categories: Connections, Performance, Troubleshooting, Errors.

### 2.5. Contribution Guide

- Content from `CONTRIBUTING.md`.
- Automated link to "Open Issues" on GitHub.

## 3. Design & UI Components

### 3.1. Sidebar Layout

- Left-hand navigation (desktop) with mobile hamburger menu.
- Active state highlighting.
- Collapsible categories.

### 3.2. Content Area

- Clean typography for long-form reading.
- Syntax highlighting for code blocks (using Prism.js or similar).
- Copy-to-clipboard buttons for every command.
- "Edit this page" link pointing to the source in `MySQLTuner-perl`.

### 3.3. Search Overlay

- Command+K shortcut to open.
- Real-time result filtering.

### 3.4. Brand Assets

- **Primary Logo**: `assets/img/mtlogo2.png` is the official brand asset for the header branding.
- **Secondary Assets**: `assets/img/logo.png` (legacy) and `assets/img/hero-bg.png` (hero background).

### 4.1. Tech Stack (PHP + Vanilla)

- **Language**: PHP 7.4+ (Standard web server support).
- **Routing**: Server-side routing via `index.php` using query parameters (e.g., `?p=overview`).
- **Markdown Processing**: Server-side rendering using `Parsedown.php` (single-file library).
- **Styling**: Vanilla CSS with modern technical dark-mode aesthetic.
- **Interactivity**: Minimal vanilla JavaScript for mobile navigation and smooth scrolling.

### 4.2. Layout Engine

- Unified layout template for all doc pages.
- Dynamic content injection into `#main-content`.

## 5. Content Mapping (Source -> Site)

| Source File | Site Path |
| :--- | :--- |
| `MySQLTuner-perl/README.md` | `/docs/overview` |
| `MySQLTuner-perl/INTERNALS.md` | `/docs/internals` |
| `MySQLTuner-perl/USAGE.md` | `/docs/usage` |
| `MySQLTuner-perl/releases/*.md` | `/releases/[v]` |
| `MySQLTuner-perl/mariadb_support.md` | `/support/mariadb` |
| `MySQLTuner-perl/mysql_support.md` | `/support/mysql` |

## 6. Success Criteria

- Instant navigation between documentation sections (LCP < 100ms for subpages).
- Search results appear in < 50ms.
- 100% of technical content from the perl repo is accessible on the site.
