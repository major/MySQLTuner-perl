---
trigger: always_on
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

### **4.2. Coding Guidelines**

- **SOLID Principles**: Follow Single Responsibility, Open-Closed, Liskov Substitution, Interface Segregation, and Dependency Inversion principles.
- **DRY (Don't Repeat Yourself)**: Avoid code duplication; extract common logic into reusable functions within the single file.
- **KISS (Keep It Simple, Stupid)**: Strive for simplicity. Avoid over-engineering.
- **Clean Code**: Write readable, self-documenting code with meaningful names and small functions.
- **Perl Tidy**: Use `perltidy` with the project's specific configuration to ensure consistent formatting across the single-file architecture.
- **Error Handling**: Implement robust error handling and logging. Use low-cardinality logging with stable message strings.

#### **Core Best Practices:**

1. **Validation Multi-Version Systématique**: Tout changement dans la logique de diagnostic doit être testé contre au moins une version "Legacy" (ex: MySQL 5.7) et une version "Moderne" (ex: MariaDB 11.4) via la suite de tests Docker (`make test-it`).
2. **Résilience des Appels Système**: Chaque commande externe (`sysctl`, `ps`, `free`, `mysql`) doit impérativement être protégée par une vérification de l'existence du binaire et une gestion d'erreur (exit code non nul) pour éviter les sorties "polluées" dans le rapport final.
3. **Politique "Zéro-Dépendance" CPAN**: Interdire l'usage de modules Perl qui ne font pas partie du "Core" (distribution standard Perl) afin que `mysqltuner.pl` reste un script unique, copiable et exécutable instantanément sur n'importe quel serveur sans installation préalable.
4. **Traçabilité des Conseils (Audit Trail)**: Chaque recommandation ou conseil affiché par le script doit être documenté dans le code par un commentaire pointant vers la source officielle (Documentation MySQL/MariaDB ou KB) pour justifier le seuil choisi.
5. **Efficience Mémoire (Parsing de Log)**: Pour le traitement des fichiers de logs (souvent volumineux), privilégier systématiquement le traitement ligne par ligne plutôt que le chargement complet en mémoire, surtout lors de la récupération via `--container`.
6. **Standardisation @Changelog**: Maintenir le `@Changelog` en suivant strictement le format des _Conventional Commits_ (feat, fix, chore, docs) pour permettre une extraction automatisée et propre des notes de version lors des tags Git.

### **4.3. Output & Restitution Format**

1. **NO CHATTER:** No intro or conclusion sentences.
2. **CODE ONLY:** Use Search_block / replace_block format for files > 50 lines.
3. **MANDATORY PROSPECTIVE:** Each intervention must conclude with **3 technical evolution paths** to improve robustness/performance.
4. **MEMORY UPDATE:** Include the JSON MEMORY_UPDATE_PROTOCOL block at the very end.

### **4.4. Development Workflow**

1. **Validation by Proof:** All changes must be verifiable via `make test-*` or dedicated test scripts.
2. **Git Protocol:**

- **STRICT PROHIBITION:** No `git commit`, `git push`, or `git tag` without using `/git-flow` or an explicit user order.
- **Conventional Commits:** Use `feat:`, `fix:`, `chore:`, `docs:`, `perf:`, `refactor:`, `style:`, `test:`, `ci:`. Breaking changes must be marked with `!` after type/scope or `BREAKING CHANGE:` in footer.
- **Commit Validation:** Commits are automatically linted via `commitlint`. Non-compliant messages will be rejected by the pre-commit hook.
- **History Documentation:** Use `npm run commit` to generate structured history.

1. **Changelog:** All changes MUST be traced and documented inside `@Changelog`.
    - _Exception_: Documentation-only updates (`docs:`) following Conventional Commits may skip the manual `@Changelog` entry if they are primarily intended for README synchronization.
