# Issue #1023: Build Stack Rationalization (Python/Bash -> Pure Perl Migration) (Phase 30.1 & 30.2)

**Type:** Architecture / Toolchain Rationalization  
**Component:** `build/release_gen.pl`, `build/genFeatures.pl`, `Makefile`, `build/dev_sync.pl`, `tests/unit_release_gen.t`  
**Assignee:** jmrenouard  
**Labels:** `build`, `ci`, `perl`, `rationalization`, `release`  

## 🎯 Description & Objectives
The MySQLTuner project strictly enforces a zero-dependency, Perl-first architecture. However, several build and maintenance utilities in `build/` relied on Python 3 (`build/release_gen.py`) and Bash pipelines (`build/genFeatures.sh`), creating unnecessary multi-language dependencies for developers and CI runners.

This phase migrates:
1. `build/release_gen.py` -> `build/release_gen.pl` in pure Perl (Core modules only: `POSIX`, `File::Spec`, `FindBin`, `Getopt::Long`, `Cwd`) with 100% output parity.
2. `build/genFeatures.sh` -> `build/genFeatures.pl` in pure Perl.
3. Updates `Makefile`, `.husky/post-commit`, `build/dev_sync.pl`, and documentation to invoke `perl build/release_gen.pl` and `perl build/genFeatures.pl`.
4. Creates dedicated TAP unit test `tests/unit_release_gen.t` to ensure long-term stability and regression resistance.

## 🧪 Acceptance Criteria
- [x] `build/release_gen.pl` implements all features: changelog parsing, conventional commit categorization, diagnostic growth indicators calculation, CLI options delta detection.
- [x] `build/genFeatures.pl` extracts features from `mysqltuner.pl` into `FEATURES.md` in pure Perl.
- [x] All build targets in `Makefile` and `build/dev_sync.pl` updated to use `perl build/release_gen.pl` and `perl build/genFeatures.pl`.
- [x] TAP test suite `tests/unit_release_gen.t` passing.
