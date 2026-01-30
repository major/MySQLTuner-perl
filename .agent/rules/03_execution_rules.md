---
trigger: always_on
description: Core project constitution and hard execution constraints.
category: governance
---

# **AI CONTEXT SPECIFICATIONS & PROJECT CONSTITUTION**

## **4\. ⚙️ EXECUTION RULES & CONSTRAINTS**

### **4.1. Formal Prohibitions (Hard Constraints)**

1. **SINGLE FILE:** Spliting `mysqltuner.pl` into modules is **strictly prohibited**.
2. **NON-REGRESSION:** Deleting existing code is **prohibited** without relocation or commenting out.
3. **NO BACKWARDS COMPATIBILITY BY DEFAULT:** Do not add backwards compatibility unless specifically requested; update all downstream consumers.
4. **OPERATIONAL SILENCE:** Textual explanations/pedagogy are **proscribed** in the response. Only code blocks, commands, and technical results.
5. **TDD MANDATORY:** Use a TDD approach. _Do not assume_ that your solution is correct. Instead, _validate your solution is correct_ by first creating a test case and running the test case to _prove_ the solution is working as intended.
6. **WEB SEARCH:** Assume your world knowledge is out of date. Use your web search tool to find up-to-date docs and information.
7. **VERSION CONSISTENCY:** Version numbers MUST be synchronized across `CURRENT_VERSION.txt`, `Changelog`, and all occurrences within `mysqltuner.pl` (Header, internal variable, and POD documentation) before any release. Use `/release-preflight` to verify.
8. **CONVENTIONAL COMMITS:** All commit messages MUST follow the [Conventional Commits](https://www.conventionalcommits.org/) specification. Use `npm run commit` for interactive commit creation. Compliance is enforced via `commitlint` and Git hooks.
9. **NO DIRECT COMMIT:** All changes MUST be committed via `npm run commit` or `git cz` to ensure metadata quality and automated changelog compatibility.
10. **VERSION SUPPORT POLICY:** Automated test example generation (via `run-tests`) MUST only target "Supported" versions of MySQL and MariaDB as defined in `mysql_support.md` and `mariadb_support.md`.

### **4.2. Spec-Driven Development (SDD) Lifecycle**

To ensure quality and clarity in every development cycle, all non-trivial features MUST follow the SDD lifecycle:

1. **Specify (`/specify`)**: Define the feature requirements, user scenarios, and stories in `documentation/specifications/`.
2. **Plan (`/plan`)**: Create a technical implementation plan in `implementation_plan.md`.
3. **Tasks (`/tasks`)**: Break down the plan into granular, ID-tracked tasks in `task.md`.
4. **Implement**: Proceed with the code changes based on the approved plan and tasks.
5. **Verify**: Validate the implementation through TDD and regression suites.

### **4.3. Coding Guidelines**

- **SOLID Principles**: Follow Single Responsibility, Open-Closed, Liskov Substitution, Interface Segregation, and Dependency Inversion principles.
- **DRY (Don't Repeat Yourself)**: Avoid code duplication; extract common logic into reusable functions within the single file.
- **KISS (Keep It Simple, Stupid)**: Strive for simplicity. Avoid over-engineering.
- **Clean Code**: Write readable, self-documenting code with meaningful names and small functions.
- **Perl Tidy**: Use `perltidy` with the project's specific configuration to ensure consistent formatting across the single-file architecture.
- **Error Handling**: Implement robust error handling and logging. Use low-cardinality logging with stable message strings.

#### **Core Best Practices:**

1. **Validation Multi-Version Systématique**: Tout changement dans la logique de diagnostic doit être testé contre au moins une version "Legacy" (ex: MySQL 8.0) et une version "Moderne" (ex: MariaDB 11.4) via la suite de tests Docker (`make test-it`).
2. **Résilience des Appels Système**: Chaque commande externe (`sysctl`, `ps`, `free`, `mysql`) doit impérativement être protégée par une vérification de l'existence du binaire et une gestion d'erreur (exit code non nul) pour éviter les sorties "polluées" dans le rapport final.
3. **Politique "Zéro-Dépendance" CPAN**: Interdire l'usage de modules Perl qui ne font pas partie du "Core" (distribution standard Perl) afin que `mysqltuner.pl` reste un script unique, copiable et exécutable instantanément sur n'importe quel serveur sans installation préalable.
4. **Traçabilité des Conseils (Audit Trail)**: Chaque recommandation ou conseil affiché par le script doit être documenté dans le code par un commentaire pointant vers la source officielle (Documentation MySQL/MariaDB ou KB) pour justifier le seuil choisi.
5. **Efficience Mémoire (Parsing de Log)**: Pour le traitement des fichiers de logs (souvent volumineux), privilégier systématiquement le traitement ligne par ligne plutôt que le chargement complet en mémoire, surtout lors de la récupération via `--container`.
6. **Standardisation @Changelog et Release Notes**: Maintenir le `@Changelog` et les notes de version (`releases/`) en suivant strictement le format des _Conventional Commits_ et l'ordre de priorité (chore, feat, fix, test, ci) pour permettre une extraction automatisée et propre.
7. **Traçabilité des Tests**: Toute exécution de test en laboratoire doit impérativement capturer les logs d'infrastructure (docker start, db injection, container logs/inspect) et les lier dans le rapport HTML final.
8. **Reproductibilité des Rapports**: Les rapports HTML doivent inclure une section "Reproduce" listant l'intégralité des commandes (git clone, setup, injection, exécution) permettant de rejouer le test à l'identique.
9. **KISS & Context**: Les recommandations de tuning noyau (kernel tuning) doivent être ignorées en mode container ou via l'option `--container` pour éviter des conseils non pertinents.

### **4.3. Output & Restitution Format**

1. **NO CHATTER:** No intro or conclusion sentences.
2. **CODE ONLY:** Use Search_block / replace_block format for files > 50 lines.
3. **MANDATORY PROSPECTIVE:** Each intervention must conclude with **3 technical evolution paths** to improve robustness/performance.
4. **Compliance Sentinel Mandatory**: The `/compliance-sentinel` workflow MUST be successful before any major commit or release, ensuring adherence to the core constitution and dynamic rules from `remembers.md`.
5. **MEMORY UPDATE:** Include the JSON MEMORY_UPDATE_PROTOCOL block at the very end.

### **4.4. Development Workflow**

1. **Validation by Proof:** All changes must be verifiable via `make test-*` or dedicated test scripts.
2. **Git Protocol:**

- **STRICT PROHIBITION:** No `git commit`, `git push`, or `git tag` without using `/git-flow` or an explicit user order.
- **Conventional Commits:** Use `feat:`, `fix:`, `chore:`, `docs:`, `perf:`, `refactor:`, `style:`, `test:`, `ci:`. Breaking changes must be marked with `!` after type/scope or `BREAKING CHANGE:` in footer.
- **Commit Validation:** Commits are automatically linted via `commitlint`. Non-compliant messages will be rejected by the pre-commit hook.
- **History Documentation:** Use `npm run commit` to generate structured history.

1. **Changelog:** All changes MUST be traced and documented inside `@Changelog`.
    - _Exception_: Documentation-only updates (`docs:`) following Conventional Commits may skip the manual `@Changelog` entry if they are primarily intended for README synchronization.
    - _Requirement_: Adding a new test MUST have a `test:` entry in the `@Changelog`.
    - _Requirement_: Changing test scripts or updating infrastructure MUST have a `ci:` entry in the `@Changelog`.
    - _Requirement_: Changing `Makefile` or files under `build/` MUST be traced in the `@Changelog` (usually via `ci:` or `chore:`).
    - _Ordering_: Changelog entries MUST be ordered by category: `chore`, `feat`, `fix`, `test`, `ci`, then others.
    - _Release Notes_: All release notes generated in `releases/` MUST follow the same category ordering in their "Executive Summary" section.
    - _Requirement_: The `/git-flow` workflow MUST always be preceded by a successful `/release-preflight` execution.
    - _Requirement_: Report files (HTML and logs) MUST NOT contain negative keywords (error, warning, fatal, failed) unless they are expected as part of a reproduction test case.
