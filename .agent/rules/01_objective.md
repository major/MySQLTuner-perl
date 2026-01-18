## **2\. 🎯 OPERATIONAL OBJECTIVE**

$$DYNAMIC\_CONTEXT$$

* **Status:** \[IN PROGRESS\]  
* **Priority Task:** Maintain and enhance `mysqltuner.pl`, a Perl script for MySQL/MariaDB database performance tuning. Ensure single-file architecture and high reliability through automated testing.

**Success Criteria:**

1. **Architecture:** No splitting of the main file; all logic resides in `mysqltuner.pl`.
2. **Quality:** 100% of new features validated through TDD.
3. **Docs:** Keep `README.md` and translations updated with new features and requirements.
4. **Automation:** All tests runnable via `make test-*` or specific test scripts.
5. **Goal:** Provide the most accurate and up-to-date performance tuning recommendations for MySQL-compatible databases.

**Roadmap / Evolution Paths:**

1. **Schema Validation for Rules**: Créer un script de linting pour valider que les fichiers `.agent/rules/*.md` respectent un format standard.
2. **Source Code Annotation**: Automatiser l'ajout des tags de version directement dans les commentaires des fonctions modifiées.
3. **Automated Doc-Link Check**: Ajouter un test qui vérifie que les liens de documentation insérés dans les commentaires du code (`# See: http://...`) sont toujours valides.
4. **Pre-commit Hook**: Implementer un hook Git local qui lance le pre-flight check de `/git-flow`.
5. **Automated Roadmap Tracking**: Créer un script qui extrait les points de la roadmap pour générer un rapport de progression.
6. **Perl Tidy Integration**: Ajouter une règle exigeant l'utilisation de `perltidy` avec une configuration spécifique pour garantir la lisibilité du fichier unique.
