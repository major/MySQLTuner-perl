# Issue #1033: Pure Perl Interactive Release Orchestrator (Phase 20.1 & 20.2)

**Type:** Feature / Release Automation  
**Component:** `build/release_orchestrator.pl`, `tests/unit_release_orchestrator.t`  
**Assignee:** jmrenouard  
**Labels:** `release`, `automation`, `orchestrator`, `semver`, `build`  

## Goal
To provide a unified, automated release orchestration engine in pure Perl that calculates semantic version bumps, updates all 6 reference locations in lockstep, triggers release notes generation, and executes pre-publish validation.

## Description & Objectives
Phase 20 specifies:
1. `build/release_orchestrator.pl`: Pure Perl orchestrator providing:
   - Automated semantic version calculation: `--bump=micro` (2.9.3 -> 2.9.4), `--bump=minor` (2.9.3 -> 2.10.0), `--bump=major` (2.9.3 -> 3.0.0), or explicit `--version=X.Y.Z`.
   - Simultaneous synchronization across all 6 reference locations (`CURRENT_VERSION.txt`, `mysqltuner.pl` [Header, `$tunerversion`, POD Name, POD VERSION], `Changelog`, `releases/v<VERSION>.md`).
   - `--dry-run` simulation mode without file modifications.
   - Automatic execution of `release_gen.pl` and `validate_release.pl`.
2. Strict zero non-core CPAN dependency compliance.
3. Dedicated TAP test suite `tests/unit_release_orchestrator.t`.

## Implementation Details
- Implemented `build/release_orchestrator.pl` using standard Perl Core modules (`Getopt::Long`, `File::Spec`, `Cwd`, `POSIX`).
- Integrated automated verification and dry-run safety checks.

## Verification
- Run `perl build/release_orchestrator.pl --dry-run --bump=micro`
- Run `prove tests/unit_release_orchestrator.t`

## Acceptance Criteria
- [x] `build/release_orchestrator.pl` implemented in pure Perl (Core only).
- [x] Semantic version bumping and artifact synchronization supported.
- [x] TAP test suite `tests/unit_release_orchestrator.t` passing.
