# Issue #1031: Dynamic Help Screen Anchors & KB References (Phase 18.2)

**Type:** Feature / Documentation & CLI  
**Component:** `mysqltuner.pl`, `tests/unit_doc_anchors.t`  
**Assignee:** jmrenouard  
**Labels:** `cli`, `help`, `anchors`, `documentation`, `kb`  

## Goal
To enrich MySQLTuner CLI help screens and tuning diagnostic sections with standardized documentation anchors and Knowledge Base URLs.

## Description & Objectives
Phase 18.2 specifies:
1. `mysqltuner.pl` helper functions:
   - `get_doc_anchor($topic)`: Returns standard reference anchor tags (e.g., `[REF: INNODB-BUFFER-POOL]`, `[REF: QUERY-CACHE]`, `[REF: REPLICATION-LAG]`, `[REF: SECURITY-AUTH]`, `[REF: CONNECTION-LIMITS]`).
   - `get_doc_url($topic)`: Returns official MySQL / MariaDB documentation links for the corresponding topic.
   - Dynamic enrichment in CLI help output (`--help` or `-h`).
2. Preservation of single-file architecture and zero non-core dependencies.
3. Dedicated TAP test suite `tests/unit_doc_anchors.t`.

## Implementation Details
- Implemented `get_doc_anchor()` and `get_doc_url()` in `mysqltuner.pl`.
- Integrated reference anchors into diagnostic reporting blocks and CLI help screens.

## Verification
- Run `prove tests/unit_doc_anchors.t`
- Run `perl mysqltuner.pl --help`

## Acceptance Criteria
- [x] `get_doc_anchor` and `get_doc_url` implemented in `mysqltuner.pl`.
- [x] Reference anchors map cleanly to official database documentation.
- [x] TAP test suite `tests/unit_doc_anchors.t` passing.
