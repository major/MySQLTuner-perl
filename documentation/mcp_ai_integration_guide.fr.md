# Guide d'Intégration Agent IA & Serveur Model Context Protocol (MCP)

Ce document fournit la documentation technique complète pour intégrer MySQLTuner avec des agents d'Intelligence Artificielle (IA), des assistants de code LLM (Claude Desktop, Cursor, VS Code, Antigravity) et des pipelines d'administration automatique de bases de données via le protocole **Model Context Protocol (MCP)** et la télémétrie CLI `--agent-json`.

---

## 🏗️ Vue d'Ensemble de l'Architecture

MySQLTuner propose une pile d'intégration IA conteneurisée et sans dépendance externe. Elle fait le pont entre la base de données et les clients IA.

```mermaid
graph TD
    subgraph "Couche Client IA"
        Claude[Claude Desktop]
        Cursor[Cursor IDE]
        VSCode[VS Code / Cline / Roo Code]
        Custom[Pipeline LLM Personnalisé]
    end

    subgraph "Serveur MCP (build/mcp_server.py)"
        JSONRPC[Interface stdio JSON-RPC 2.0]
        Daemon[Démon d'Audit en Arrière-plan]
        CacheManager[Gestionnaire de Cache JSON / HTML]
        RollbackEngine[Moteur de Rollback & Transactions]
    end

    subgraph "Base de Données & Moteur"
        PerlEngine[Moteur Perl MySQLTuner (mysqltuner.pl)]
        MySQLInstance[(MySQL / MariaDB / Percona Server)]
    end

    Claude <-->|stdio JSON-RPC| JSONRPC
    Cursor <-->|stdio JSON-RPC| JSONRPC
    VSCode <-->|stdio JSON-RPC| JSONRPC
    Custom <-->|stdio JSON-RPC| JSONRPC

    JSONRPC --> Daemon
    Daemon -->|Exécute --agent-json| PerlEngine
    PerlEngine -->|Télémétrie SQL| MySQLInstance
    PerlEngine -->|JSON Structuré| CacheManager
    CacheManager -->|Ressources & Recommandations| JSONRPC
    RollbackEngine -->|SET GLOBAL / Annulation| MySQLInstance
```

---

## ⚡ Mode 1 : Intégration Directe CLI (`--agent-json`)

Lorsqu'il est invoqué avec l'option `--agent-json`, `mysqltuner.pl` supprime toutes les sorties ANSI formatées pour le terminal et émet un schéma JSON structuré unique conçu pour être consommé directement par les agents IA.

### Commande CLI
```bash
perl mysqltuner.pl --agent-json --host <db_host> --user <db_user> --pass <db_pass>
```

### Structure du Schéma JSON
```json
{
  "findings": [
    {
      "id": "innodb_buffer_pool_size_adjust",
      "topic": "Performance",
      "description": "La taille du buffer pool InnoDB est sous-dimensionnée pour la charge actuelle.",
      "impact_score": 9,
      "risk_level": "Medium",
      "risk_description": "Augmente la consommation mémoire. Assurez-vous d'avoir suffisamment de RAM libre sur le système.",
      "requires_restart": false,
      "expected_outcome": "Réduit les E/S disque et augmente le taux de succès du cache.",
      "action": {
        "type": "SQL",
        "statement": "SET GLOBAL innodb_buffer_pool_size = 1073741824;",
        "rollback_statement": "SET GLOBAL innodb_buffer_pool_size = 134217728;"
      }
    }
  ]
}
```

---

## 🔌 Mode 2 : Serveur Model Context Protocol (MCP)

Le serveur MCP ([build/mcp_server.py](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/build/mcp_server.py)) implémente le standard MCP sur le transport `stdio` en utilisant le protocole JSON-RPC 2.0.

### Ressources MCP Exposées

| Ressource URI | Type de Contenu | Description |
| :--- | :--- | :--- |
| `mysqltuner://reports/latest.json` | `application/json` | Accède aux derniers résultats d'audit et à l'état des variables. |
| `mysqltuner://reports/latest.html` | `text/html` | Récupère le rapport analytique interactif au format HTML. |
| `mysqltuner://indicators/summary.json` | `application/json` | Fournit les indicateurs KPI principaux (Performance, Sécurité, Résilience). |

### Outils MCP Exposés

1. **`get_latest_audit`** : Récupère instantanément le dernier rapport mis en cache sans solliciter le serveur de base de données.
2. **`run_audit`** : Déclenche une nouvelle exécution de `mysqltuner.pl --agent-json` et rafraîchit le cache.
3. **`apply_recommendation`** : Applique une modification SQL dynamique (`SET GLOBAL`).
4. **`rollback_recommendation`** : Annule une modification précédemment appliquée en utilisant l'état de transaction sauvegardé.

---

## 🚀 Guide de Déploiement

### Déploiement Microservice Conteneurisé

L'image Docker officielle ([Dockerfile.mcp](file:///home/jmren/GIT_REPOS/MySQLTuner-perl/Dockerfile.mcp)) regroupe Perl, Python 3, mysql-client et le serveur MCP.

```bash
docker run -d \
  --name mysqltuner-mcp \
  -e DB_HOST=mysql-server \
  -e DB_PORT=3306 \
  -e DB_USER=root \
  -e DB_PASSWORD=secret_pass \
  -e AUDIT_INTERVAL_HOURS=6 \
  -v /var/cache/mysqltuner:/var/cache/mysqltuner \
  mysqltuner-mcp
```

---

## 🛡️ Consignes et Prompt Système pour l'Agent IA

Injectez ce prompt système dans votre environnement client LLM pour garantir une administration sécurisée :

```markdown
Vous êtes un Administrateur de Bases de Données (DBA) Principal. Vous avez accès au serveur MCP MySQLTuner.

### Règles de Sécurité :
1. **Inspection Initiale** : Exécutez toujours `get_latest_audit` avant de proposer des modifications.
2. **Évaluation des Risques** :
   - Les commandes à risque `Low` / `Medium` sans redémarrage (`requires_restart: false`) peuvent être appliquées après validation de la commande de rollback par l'utilisateur.
   - Les commandes à risque `High` / `Critical` ou nécessitant un redémarrage requièrent une confirmation explicite.
3. **Vérification du Rollback** : Indiquez systématiquement la commande `statement` et sa contrepartie `rollback_statement` avant exécution.
4. **Boucle de Validation** : Après application d'une modification, exécutez `run_audit` pour vérifier l'amélioration du score KPI. En cas de régression, exécutez immédiatement `rollback_recommendation`.
```
