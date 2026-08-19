# Agent Custom Rules

- Always update technical release notes (`releases/v[VERSION].md`) simultaneously with `Changelog` updates.
- Enforce strict incremental semantic versioning across `CURRENT_VERSION.txt`, `Changelog`, `releases/v[VERSION].md`, and `mysqltuner.pl`.
- Enforce Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `perf:`, `test:`, `ci:`) via `@commitlint/cz-commitlint` and `npm run commit`.
- Enforce branching rules (no direct commits to `master`) and force-push synchronized `vX.Y.Z` Git release tags via `/release-manager`.
- Decompose unit tests into human-assimilable parts (for example, using structured subtests).
- Systematically add unit tests to validate every code modification.
- For each modification, add an issue with the correct tags in Major's project and assign it to jmrenouard.

