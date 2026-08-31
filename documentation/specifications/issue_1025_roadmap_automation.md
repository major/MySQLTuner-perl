# Issue #1025: Structured Roadmap Automation & Schema Validation (Phase 21)

**Type:** Feature / Quality Gate Automation  
**Component:** `build/validate_roadmap.pl`, `tests/unit_roadmap_validation.t`, `Makefile`  
**Assignee:** jmrenouard  
**Labels:** `roadmap`, `schema`, `validation`, `automation`, `qa`  

## 🎯 Description & Objectives
The project's strategic roadmap (`ROADMAP.md`) serves as the foundation for release management, feature tracking, and specification linking. To ensure its integrity over time, Phase 21 specifies:
1. A structured schema validator `build/validate_roadmap.pl` (written in pure Perl) verifying:
   - Proper phase numbering and header syntax (`### Phase XX: ... [STATUS]`)
   - Valid status values (`[COMPLETED]`, `[IN PROGRESS]`, `[NOT STARTED]`)
   - Valid checkbox item formatting (`* [x] ...` or `* [ ] ...`)
   - Verification of linked file references (`documentation/specifications/...`) ensuring zero broken links.
2. Comprehensive TAP unit test `tests/unit_roadmap_validation.t` validating all schema checks.

## 🧪 Acceptance Criteria
- [x] `build/validate_roadmap.pl` implemented in pure Perl (Core modules only).
- [x] Validates phase headers, statuses, checkboxes, and specification file existence.
- [x] Returns exit code 0 on valid roadmap, non-zero with descriptive errors on invalid syntax or broken links.
- [x] TAP test suite `tests/unit_roadmap_validation.t` passing.
