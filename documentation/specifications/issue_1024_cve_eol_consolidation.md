---
test_file: tests/unit_cve_update.t
---

# Issue #1024: Multi-Language Normalization & EOL/CVE Consolidation (Phase 27 & 30.4)

**Type:** Maintenance / Toolchain Consolidation  
**Component:** `build/sync_eol_dates.pl`, `build/updateCVElist.pl`, `build/get_version.sh`, `Makefile`  
**Assignee:** jmrenouard  
**Labels:** `cve`, `eol`, `maintenance`, `toolchain`, `perl`  

## Goal
Enforce zero-dependency CPAN and Perl-first policy across all developer tools by consolidating EOL/CVE data fetching into pure Perl and removing redundant legacy multi-language scripts.

## Description & Objectives
To enforce the single-file, zero-dependency CPAN and Perl-first policy across all developer tools:
1. Merge `endoflife.sh` (Bash + curl + jq) into `build/sync_eol_dates.pl` using standard Core `HTTP::Tiny` and `JSON::PP`.
2. Update `build/updateCVElist.pl` to use Core `HTTP::Tiny` and `JSON::PP` (removing non-core `LWP::UserAgent` and `JSON`). Remove obsolete `build/updateCVElist.py`.
3. Create centralized `build/get_version.sh` for reliable version extraction.
4. Remove orphan files (`JenkinsFile`, `tests/unit_versions.t.bak`, `build/genFeatures.sh`, `build/endoflife.sh`).
5. Update `Makefile` target `generate_eof_files` to use `perl ./build/sync_eol_dates.pl --generate`.

## Implementation Details
- Merged EOL generation logic into `build/sync_eol_dates.pl`.
- Standardized `build/updateCVElist.pl` to use Core modules only.
- Pruned obsolete and temporary build artifacts.

## Verification
- Run `prove tests/unit_cve_update.t`

## Acceptance Criteria
- [x] `build/sync_eol_dates.pl` can generate `mysql_support.md` and `mariadb_support.md` directly in pure Perl.
- [x] `build/updateCVElist.pl` uses only Perl Core modules (`HTTP::Tiny`, `JSON::PP`).
- [x] `build/get_version.sh` created and executable.
- [x] Orphan files (`JenkinsFile`, `tests/unit_versions.t.bak`, `build/updateCVElist.py`, `build/endoflife.sh`, `build/genFeatures.sh`) removed.
- [x] Unit test `tests/unit_cve_update.t` validates scripts compilation and pure Perl execution.
