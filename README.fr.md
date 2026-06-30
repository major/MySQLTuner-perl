![MySQLTuner-perl](mtlogo2.png)

[![GitHub stars](https://img.shields.io/github/stars/major/MySQLTuner-perl?style=for-the-badge&logo=github)](https://github.com/major/MySQLTuner-perl)

[![État du projet](https://opensource.box.com/badges/active.svg)](https://opensource.box.com/badges)
[![État des tests](https://github.com/major/MySQLTuner-perl/actions/workflows/pull_request.yml/badge.svg)](https://github.com/major/MySQLTuner-perl/actions)
[![Temps moyen de résolution d'un problème](https://isitmaintained.com/badge/resolution/major/MySQLTuner-perl.svg)](https://isitmaintained.com/project/major/MySQLTuner-perl "Temps moyen de résolution d'un problème")
[![Pourcentage de problèmes ouverts](https://isitmaintained.com/badge/open/major/MySQLTuner-perl.svg)](https://isitmaintained.com/project/major/MySQLTuner-perl "Pourcentage de problèmes encore ouverts")
[![Licence GPL](https://badges.frapsoft.com/os/gpl/gpl.png?v=103)](https://opensource.org/licenses/GPL-3.0/)

**MySQLTuner** est un script écrit en Perl qui vous permet d'examiner rapidement une installation MySQL et de faire des ajustements pour augmenter les performances et la stabilité. Les variables de configuration actuelles et les données d'état sont récupérées et présentées dans un bref format avec quelques suggestions de performances de base.

**MySQLTuner** prend en charge environ 900+ indicateurs, KPI et recommandations (y compris le score de santé pondéré, la planification prédictive des capacités et l'audit SSL/TLS) pour MySQL/MariaDB/Percona Server dans cette dernière version.

**MySQLTuner** est activement maintenu et prend en charge de nombreuses configurations telles que [Galera Cluster](https://galeracluster.com/), [TokuDB](https://www.percona.com/software/mysql-database/percona-tokudb), [Schéma de performance](https://github.com/mysql/mysql-sys), les métriques du système d'exploitation Linux, [InnoDB](https://dev.mysql.com/doc/refman/5.7/en/innodb-storage-engine.html), [MyISAM](https://dev.mysql.com/doc/refman/5.7/en/myisam-storage-engine.html), [Aria](https://mariadb.com/docs/server/server-usage/storage-engines/aria/aria-storage-engine), ...

Vous pouvez trouver plus de détails sur ces indicateurs ici :
[Description des indicateurs](https://github.com/major/MySQLTuner-perl/blob/master/INTERNALS.md).

![MysqlTuner](https://github.com/major/MySQLTuner-perl/blob/master/mysqltuner.png)

Liens utiles
==

* **Développement actif :** [https://github.com/major/MySQLTuner-perl](https://github.com/major/MySQLTuner-perl)
* **Versions/Tags :** [https://github.com/major/MySQLTuner-perl/tags](https://github.com/major/MySQLTuner-perl/tags)
* **Changelog :** [https://github.com/major/MySQLTuner-perl/blob/master/Changelog](https://github.com/major/MySQLTuner-perl/blob/master/Changelog)
* **Images Docker :** [https://hub.docker.com/repository/docker/jmrenouard/mysqltuner/tags](https://hub.docker.com/repository/docker/jmrenouard/mysqltuner/tags)

MySQLTuner a besoin de vous
===

**MySQLTuner** a besoin de contributeurs pour la documentation, le code et les commentaires :

* Veuillez nous rejoindre sur notre outil de suivi des problèmes sur [le suivi GitHub](https://github.com/major/MySQLTuner-perl/issues).
* Le guide de contribution est disponible en suivant [le guide de contribution de MySQLTuner](https://github.com/major/MySQLTuner-perl/blob/master/CONTRIBUTING.md)
* Mettez une étoile au **projet MySQLTuner** sur [le projet Git Hub de MySQLTuner](https://github.com/major/MySQLTuner-perl/)
* Support payant pour LightPath ici : [jmrenouard@lightpath.fr](jmrenouard@lightpath.fr)
* Support payant pour Releem disponible ici : [Application Releem](https://releem.com/)

### Sponsors

Le développement actif est sponsorisé par :

<p align="center">
  <a href="https://www.lightpath.fr">
    <img src="https://lightpath.fr/img/logo.png" alt="LightPath" width="200"/>
  </a>
</p>

Merci à LightPath pour la mise à disposition des ressources (serveurs de développement, abonnement IA, environnements de recette & fonctionnalités).

![Statistiques GitHub de jmrenouard](https://github-readme-stats.vercel.app/api?username=jmrenouard&show_icons=true&theme=radical)

[!["Offrez-nous un café"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/jmrenouard)

## Historique des étoiles

[![Star History Chart](https://api.star-history.com/svg?repos=major/MySQLTuner-perl&type=Date)](https://star-history.com/#major/MySQLTuner-perl&Date)

Compatibilité
====

Les résultats des tests sont disponibles ici uniquement pour les versions LTS :

* MySQL (prise en charge complète)
* Percona Server (prise en charge complète)
* MariaDB (prise en charge complète)
* Réplication Galera (prise en charge complète)
* Cluster Percona XtraDB (prise en charge complète)
* Réplication MySQL (prise en charge partielle, pas d'environnement de test)

Merci à [endoflife.date](https://endoflife.date/)

* Reportez-vous aux [versions prises en charge de MariaDB](https://github.com/major/MySQLTuner-perl/blob/master/mariadb_support.md).
* Reportez-vous aux [versions prises en charge de MySQL](https://github.com/major/MySQLTuner-perl/blob/master/mysql_support.md).

***La prise en charge de Windows est partielle***

* Windows est maintenant pris en charge à ce moment
* Exécution réussie de MySQLtuner sur WSL2 (sous-système Windows pour Linux)
* [https://docs.microsoft.com/en-us/windows/wsl/](https://docs.microsoft.com/en-us/windows/wsl/)

***ENVIRONNEMENTS NON PRIS EN CHARGE - BESOIN D'AIDE POUR CELA***

***Intelligence avancée et écosystème***

* **Indicateur de score de santé pondéré (KPI)** : Évaluation globale de la santé de la base de données (0-100) basée sur les performances (40pts), la sécurité (30pts) et la résilience (30pts).
* **Conseiller en migration intelligente LTS** : Identification des risques lors de la migration vers les versions LTS modernes (MySQL 8.4/9.0+, MariaDB 11.x), incluant les variables supprimées et les méthodes d'authentification dépréciées.
* **Planification prédictive des capacités** : Analyse de la marge de manœuvre mémoire (pic vs RAM+Swap disponible), prévision de la croissance disque, et détection de la capacité AUTO_INCREMENT proche du maximum.
* **Découverte automatique du Cloud** : Prise en charge native d'AWS RDS/Aurora, GCP Cloud SQL, Azure (Flexible/Managed) et DigitalOcean. Détection automatique via `@@version_comment` et variables spécifiques au fournisseur.
* **Tuning adaptatif à l'infrastructure** : Détection des types de stockage SSD/NVMe vs HDD et des architectures ARM64/Graviton vs x86_64. Ajustement des recommandations pour `innodb_flush_neighbors` et `innodb_io_capacity`.
* **Audit de sécurité SSL/TLS** : Vérification du chiffrement de session, audit des versions TLS (alerte sur TLSv1.0/1.1), expiration des certificats, application de `require_secure_transport`, et vérification SSL des utilisateurs distants.
* **Audit des plugins d'authentification** : Détection des plugins non sécurisés (`mysql_native_password`, `sha256_password`), diagnostic de compatibilité MySQL 9.x, et recommandations MariaDB `ed25519`/`unix_socket`.
* **Modélisation de schéma et conventions de nommage** : Analyse complète de la structure des tables (PK manquantes, types de clés de substitution, conformité UTF-8, tables non-InnoDB), audit des conventions de nommage (cohérence snake_case/camelCase, détection du pluriel, préfixes de colonnes booléennes/dates), et analyse des clés étrangères (colonnes `_id` non contraintes, incohérences de types, audit CASCADE).
* **Modélisation MySQL 8.0+ / MariaDB** : Indexabilité des colonnes JSON (colonnes virtuelles générées), index invisibles, contraintes CHECK.
* **Moteur Auto-Fix guidé** : Génération d'instructions `SET GLOBAL` SQL prêtes à l'emploi et de blocs de configuration `[mysqld]` à partir des recommandations d'ajustement de variables.
* **Analyse de tendances historiques** : Ingestion de sorties JSON de runs précédents via `--compare-file` pour suivre les tendances QPS et de croissance des données.
* **Intégration Sysbench** : Analyse de la sortie sysbench pour les métriques QPS, TPS et latence (Moy/95e/Max) via `--sysbench-file`.
* **Intégration logs Container et Systemd** : Détection automatique des logs depuis Docker, Podman, Kubectl/Kubernetes et le journal Systemd.

***Moteurs de stockage non pris en charge : les PR sont les bienvenues***
--

* NDB n'est pas pris en charge, n'hésitez pas à créer une demande d'extraction
* Archive
* Spider
* ColummStore
* Connexion

Éléments non maintenus de MySQL ou MariaDB
--

* MyISAM est trop ancien et n'est plus actif
* RockDB n'est plus maintenu
* TokuDB n'est plus maintenu
* XtraDB n'est plus maintenu

* Prise en charge de la détection des vulnérabilités CVE depuis [https://cve.mitre.org](https://cve.mitre.org)

***EXIGENCES MINIMALES***

* Perl 5.6 ou version ultérieure (avec le package [perl-doc](https://metacpan.org/release/DAPM/perl-5.14.4/view/pod/perldoc.pod))
* Système d'exploitation basé sur Unix/Linux (testé sur Linux, les variantes BSD et les variantes Solaris)
* Accès en lecture illimité au serveur MySQL (voir Privilèges ci-dessous)

***PRIVILÈGES***
--

Pour exécuter MySQLTuner avec toutes les fonctionnalités, les privilèges suivants sont requis :

**MySQL 8.0+**:

```sql
GRANT SELECT, PROCESS, SHOW DATABASES, EXECUTE, REPLICATION REPLICA, REPLICATION CLIENT, SHOW VIEW ON *.* TO 'mysqltuner'@'localhost';
```

**MariaDB 10.5+**:

```sql
GRANT SELECT, PROCESS, SHOW DATABASES, EXECUTE, BINLOG MONITOR, SHOW VIEW, REPLICATION SOURCE ADMIN, REPLICA MONITOR ON *.* TO 'mysqltuner'@'localhost';
```

**Versions héritées (Legacy)**:

```sql
GRANT SELECT, PROCESS, EXECUTE, REPLICATION CLIENT, SHOW DATABASES, SHOW VIEW ON *.* TO 'mysqltuner'@'localhost';
```

Accès root au système d'exploitation recommandé pour MySQL < 5.1

***AVERTISSEMENT***
--

Il est **important** que vous compreniez parfaitement chaque modification
que vous apportez à un serveur de base de données MySQL. Si vous ne comprenez pas certaines parties
de la sortie du script, ou si vous ne comprenez pas les recommandations,
**vous devriez consulter** un DBA ou un administrateur système compétent
en qui vous avez confiance. **Testez toujours** vos modifications sur des environnements de préproduction, et
gardez toujours à l'esprit que les améliorations dans un domaine peuvent **affecter négativement**
MySQL dans d'autres domaines.

Il est **également important** d'attendre au moins 24 heures de temps de disponibilité pour obtenir des résultats précis. En fait, exécuter
**mysqltuner** sur un serveur fraîchement redémarré est complètement inutile.

**Veuillez également consulter la section FAQ ci-dessous.**

Recommandations de sécurité
--

Salut l'utilisateur de directadmin !
Nous avons détecté que vous exécutez mysqltuner avec les informations d'identification de da_admin extraites de `/usr/local/directadmin/conf/my.cnf`, ce qui pourrait entraîner une découverte de mot de passe !
Lisez le lien pour plus de détails [Problème n°289](https://github.com/major/MySQLTuner-perl/issues/289).

Que vérifie exactement MySQLTuner ?
--

Toutes les vérifications effectuées par **MySQLTuner** sont documentées dans la documentation [MySQLTuner Internals](https://github.com/major/MySQLTuner-perl/blob/master/INTERNALS.md).

**MySQLTuner** analyse les domaines suivants :

* **Système et OS** : RAM, swap, ports ouverts, paramètres noyau, charge, points de montage, cartes réseau
* **Version du serveur** : Détection EOL, architecture, recommandations 64 bits
* **Logs d'erreur** : Fichiers locaux, conteneurs Docker/Podman, pods Kubernetes, journal Systemd
* **Cloud et Infrastructure** : AWS RDS/Aurora, GCP, Azure, DigitalOcean ; SSD/NVMe vs HDD ; ARM64/x86_64
* **Moteurs de stockage** : InnoDB (buffer pool, redo log, chunk size), MyISAM, Aria, Galera, TokuDB, RocksDB
* **Sécurité** : Utilisateurs anonymes, mots de passe faibles, audit SSL/TLS, plugins d'authentification, vulnérabilités CVE
* **Connexions** : Pourcentages d'utilisation, connexions abandonnées, cache de threads
* **Performance** : Tri/jointures/tables temporaires, buffers globaux, cache de requêtes, requêtes lentes, utilisation mémoire
* **Réplication** : État Source/Réplica, retard, GTID, semi-sync, multi-source
* **Performance Schema** : Top utilisateurs/hôtes/requêtes, latence IO, verrouillages, index inutilisés, index redondants
* **Modélisation de schéma** : Analyse des clés primaires, conventions de nommage, clés étrangères, types de données, conformité UTF-8, indexabilité JSON
* **Prédictif** : Marge mémoire, prévision de croissance disque, capacité AUTO_INCREMENT
* **Score de santé** : KPI pondéré (0-100) agrégant les résultats Performance, Sécurité et Résilience

Téléchargement/Installation
--

> **Remarque :** Les paquets des distributions Linux (par exemple `apt install mysqltuner` sur Ubuntu/Debian, `yum`/`dnf` sur RHEL/CentOS/Fedora) fournissent souvent une version beaucoup plus ancienne de MySQLTuner. Il n'existe pas de dépôt officiel maintenu par les distributions qui suit la dernière version. Pour toujours obtenir la dernière version, utilisez l'une des méthodes de téléchargement direct ci-dessous.

Choisissez l'une de ces méthodes :

1) Téléchargement direct du script (la méthode la plus simple et la plus courte) :

```bash
wget https://mysqltuner.pl/ -O mysqltuner.pl
wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/basic_passwords.txt -O basic_passwords.txt
wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/vulnerabilities.csv -O vulnerabilities.csv
```

2) Vous pouvez télécharger l'intégralité du référentiel en utilisant `git clone` ou `git clone --depth 1 -b master` suivi de l'URL de clonage ci-dessus.

```bash
git clone --depth 1 -b master https://github.com/major/MySQLTuner-perl.git
```

3) Sur Apple macOS, installez via [Homebrew](https://brew.sh/) :

```bash
brew install mysqltuner
```

4) Si vous êtes dans un **environnement isolé (air-gapped)** sans accès direct à Internet, téléchargez les fichiers sur une machine disposant d'un accès Internet (ou via un hôte proxy), puis copiez `mysqltuner.pl`, `basic_passwords.txt` et `vulnerabilities.csv` sur votre serveur cible.

5) Docker : Récupérez et lancez le conteneur Docker officiel (les tags de Docker Hub sont disponibles sur [jmrenouard/mysqltuner tags](https://hub.docker.com/r/jmrenouard/mysqltuner/tags?name=latest)) :

```bash
docker pull jmrenouard/mysqltuner:latest
docker run --rm -it jmrenouard/mysqltuner --host <database_host> --user <username> --pass <password>
```

### Emplacement des versions (Releases)

* Les notes de version officielles et l'historique sont documentés dans le dossier [releases/](releases/) de ce dépôt (par exemple, [releases/v2.9.0.md](releases/v2.9.0.md)).
* Les tags de version Git et les archives sources téléchargeables sont disponibles sur [GitHub Releases](https://github.com/major/MySQLTuner-perl/releases).

Installation facultative de Sysschema pour MySQL 5.6
--

Sysschema est installé par défaut sous MySQL 5.7 et MySQL 8 d'Oracle.
Par défaut, sur MySQL 5.6/5.7/8, le schéma de performance est activé.
Pour la version précédente de MySQL 5.6, vous pouvez suivre cette commande pour créer une nouvelle base de données sys contenant une vue très utile sur le schéma de performance :

Sysschema for MySQL old version
--

```bash
curl "https://codeload.github.com/mysql/mysql-sys/zip/master" > sysschema.zip
# check zip file
unzip -l sysschema.zip
unzip sysschema.zip
cd mysql-sys-master
mysql -uroot -p < sys_56.sql
```

Sysschema pour l'ancienne version de MariaDB
--

```bash
curl "https://github.com/FromDual/mariadb-sys/archive/refs/heads/master.zip" > sysschema.zip
# check zip file
unzip -l sysschema.zip
unzip sysschema.zip
cd mariadb-sys-master
mysql -u root -p < ./sys_10.sql
```

Configuration du schéma de performance
--

Par défaut, performance_schema est activé et sysschema est installé sur la dernière version.

Par défaut, sur MariaDB, le schéma de performance est désactivé (MariaDB<10.6).

Envisagez d'activer le schéma de performance dans votre fichier de configuration my.cnf :

```ini
[mysqld]
performance_schema = on
performance-schema-consumer-events-statements-history-long = ON
performance-schema-consumer-events-statements-history = ON
performance-schema-consumer-events-statements-current = ON
performance-schema-consumer-events-stages-current=ON
performance-schema-consumer-events-stages-history=ON
performance-schema-consumer-events-stages-history-long=ON
performance-schema-consumer-events-transactions-current=ON
performance-schema-consumer-events-transactions-history=ON
performance-schema-consumer-events-transactions-history-long=ON
performance-schema-consumer-events-waits-current=ON
performance-schema-consumer-events-waits-history=ON
performance-schema-consumer-events-waits-history-long=ON
performance-schema-instrument='%=ON'
max-digest-length=2048
performance-schema-max-digest-length=2018
```

Installation de Sysschema pour MariaDB < 10.6
--

Sysschema n'est pas installé par défaut sous MariaDB avant la version 10.6 [MariaDB sys](https://mariadb.com/kb/en/sys-schema/)

Vous pouvez suivre cette commande pour créer une nouvelle base de données sys contenant une vue utile sur le schéma de performance :

```bash
curl "https://codeload.github.com/FromDual/mariadb-sys/zip/master" > mariadb-sys.zip
# check zip file
unzip -l mariadb-sys.zip
unzip mariadb-sys.zip
cd mariadb-sys-master/
mysql -u root -p < ./sys_10.sql
```

Erreurs et solutions pour l'installation du schéma de performance
--

ERREUR 1054 (42S22) à la ligne 78 dans le fichier : './views/p_s/metrics_56.sql' : Colonne inconnue 'STATUS' dans la liste des champs
--

Cette erreur peut être ignorée en toute sécurité
Envisagez d'utiliser une version récente de MySQL/MariaDB pour éviter ce genre de problème lors de l'installation de sysschema

Dans les versions récentes, sysschema est installé et intégré par défaut en tant que schéma sys (SHOW DATABASES)

ERREUR à la ligne 21 : Impossible d'ouvrir le fichier './tables/sys_config_data_10.sql -- ported', erreur : 2
Jetez un œil à la solution n°452 proposée par @ericx
--

Correction de la configuration de sysctl (/etc/sysctl.conf)

--
Il s'agit d'un paramètre à l'échelle du système et non d'un paramètre de base de données : [Paramètres du noyau FS Linux](https://www.kernel.org/doc/html/latest/admin-guide/sysctl/fs.html#id1)

Vous pouvez vérifier ses valeurs via :

```bash
$ cat /proc/sys/fs/aio-*
65536
2305
```

Par exemple, pour définir la valeur aio-max-nr, ajoutez la ligne suivante au fichier /etc/sysctl.conf :

```bash
fs.aio-max-nr = 1048576
```

Pour activer le nouveau paramètre :

```bash
sysctl -p /etc/sysctl.conf
```

Utilisation spécifique
--

**Utilisation :** Utilisation minimale localement

```bash
perl mysqltuner.pl --host 127.0.0.1
```

Bien sûr, vous pouvez ajouter le bit d'exécution (`chmod +x mysqltuner.pl`) pour pouvoir l'exécuter sans appeler Perl directement.

**Utilisation :** Utilisation minimale à distance

Dans la version précédente, --forcemem devait être défini manuellement, afin de pouvoir exécuter une analyse MySQLTuner

Depuis la version 2.1.10, la mémoire et la permutation sont définies à 1 Go par défaut.

Si vous souhaitez une valeur plus précise en fonction de votre serveur distant, n'hésitez pas à configurer --forcemem et --forceswap sur la valeur réelle de la RAM

```bash
perl mysqltuner.pl --host targetDNS_IP --user admin_user --pass admin_password
```

**Utilisation :** Activer la sortie maximale d'informations sur MySQL/MariaDb sans débogage

```bash
perl mysqltuner.pl --verbose
perl mysqltuner.pl --buffers --dbstat --idxstat --sysstat --pfstat --tbstat
```

**Utilisation :** Activer la vérification des vulnérabilités CVE pour votre version de MariaDB ou MySQL

```bash
perl mysqltuner.pl --cvefile=vulnerabilities.csv
```

**Utilisation :** Écrire votre résultat dans un fichier avec les informations affichées

```bash
perl mysqltuner.pl --outputfile /tmp/result_mysqltuner.txt
```

**Utilisation :** Écrire votre résultat dans un fichier **sans afficher d'informations**

```bash
perl mysqltuner.pl --silent --outputfile /tmp/result_mysqltuner.txt
```

**Utilisation :** Générer un rapport HTML autonome (intégré, ne nécessite aucun module CPAN ou externe)

```bash
perl mysqltuner.pl --reportfile=mysqltuner.html
```

**Utilisation :** Vidage de toutes les vues information_schema et sysschema sous forme de fichier csv dans le sous-répertoire des résultats

```bash
perl mysqltuner.pl --verbose --dumpdir=./result
```

**Utilisation :** Activer les informations de débogage

```bash
perl mysqltuner.pl --debug
```

**Utilisation :** Mettre à jour MySQLTuner et les fichiers de données (mot de passe et cve) si nécessaire

```bash
perl mysqltuner.pl --checkversion --updateversion
```

**Utilisation :** Intégration des résultats de performance Sysbench

```bash
perl mysqltuner.pl --sysbench-file=/chemin/vers/sortie_sysbench.txt
```

**Utilisation :** Analyse de tendances historiques (comparaison avec un run précédent)

```bash
perl mysqltuner.pl --json --outputfile=run1.json
# ... quelque temps plus tard ...
perl mysqltuner.pl --compare-file=run1.json
```

**Utilisation :** Exporter un fichier Markdown par schéma (documentation de schéma)

```bash
perl mysqltuner.pl --verbose --schemadir=./schemas
```

**Utilisation :** Export de données avec limite de lignes et compression gzip

```bash
perl mysqltuner.pl --verbose --dumpdir=./result --dump-limit=10000 --compress-dump
```

**Utilisation :** Mode conteneur (analyser une base de données dans Docker)

```bash
perl mysqltuner.pl --verbose --container docker:nom_du_conteneur_mysql
```

**Utilisation :** Analyse de structure de table et conventions de nommage

```bash
perl mysqltuner.pl --structstat
```

**Utilisation :** Filtrer la sortie (afficher uniquement les problèmes)

```bash
perl mysqltuner.pl --nogood --noinfo
```

**Utilisation :** Sortie JSON (pour l'automatisation et les pipelines de reporting)

```bash
perl mysqltuner.pl --json --outputfile=report.json
perl mysqltuner.pl --prettyjson
```

**Utilisation :** Mode serveur non dédié (hébergement partagé)

```bash
perl mysqltuner.pl --nondedicated
```

**Utilisation :** Utiliser des identifiants via des variables d'environnement

```bash
export MYSQL_USER=mysqltuner
export MYSQL_PASS=secret
perl mysqltuner.pl --userenv=MYSQL_USER --passenv=MYSQL_PASS
```

Pour une liste complète de toutes les options disponibles, exécutez `perl mysqltuner.pl --help` ou consultez la documentation [USAGE.md](https://github.com/major/MySQLTuner-perl/blob/master/USAGE.md).

Prise en charge du cloud
--

MySQLTuner dispose désormais d'une prise en charge expérimentale des services MySQL basés sur le cloud.

* `--cloud` : activez le mode cloud. Il s'agit d'un indicateur générique pour tout fournisseur de cloud.
* `--azure` : activez la prise en charge spécifique à Azure.
* `--ssh-host <hostname>` : l'hôte SSH pour les connexions cloud.
* `--ssh-user <username>` : l'utilisateur SSH pour les connexions cloud.
* `--ssh-password <password>` : le mot de passe SSH pour les connexions cloud.
* `--ssh-identity-file <path>` : le chemin d'accès au fichier d'identité SSH pour les connexions cloud.

Rapport HTML et score de santé pondéré
--

MySQLTuner calcule dynamiquement un **score de santé pondéré (KPI)** (évaluation globale de la santé de la base de données sur une échelle de 0 à 100) basé sur trois catégories :

1. **Performances (40 points max)** : Évaluation de l'efficacité de lecture du pool de tampons, du pourcentage de tables temporaires sur disque, du taux d'utilisation du cache de threads et de la limite de connexions.
2. **Sécurité (30 points max)** : Évaluation de la configuration des comptes utilisateurs, des mots de passe faibles (vérifiés hors ligne), du chiffrement des sessions SSL/TLS et de l'utilisation des plugins d'authentification.
3. **Résilience (30 points max)** : Évaluation de l'état et de la latence de la réplication, de la configuration des logs et des anomalies de modélisation de schéma.

**Génération du rapport HTML**

Vous pouvez générer un rapport HTML autonome directement avec :

```bash
perl mysqltuner.pl --reportfile=mysqltuner.html
```

Cette fonctionnalité est intégrée nativement en Perl pur et possède **zéro dépendance externe** (aucun module CPAN ou paquet Python n'est requis). Le rapport généré fournit un tableau de bord interactif sur thème sombre affichant :
- Une jauge de score de santé globale
- Un aperçu détaillé des métriques KPI (Performances, Sécurité, Résilience)
- Des listes de recommandations catégorisées (Général, Variables à ajuster, Modélisation de base de données, Sécurité, Système)
- Un journal complet et rétractable de la sortie console



FAQ
--

**Question : Quels sont les prérequis pour exécuter MySQL tuner ?**

Avant d'exécuter MySQL tuner, vous devez disposer des éléments suivants :

* Une installation du serveur MySQL
* Perl installé sur votre système
* Un accès administratif à votre serveur MySQL

**Question : MySQL tuner peut-il apporter des modifications à ma configuration automatiquement ?**

**Non.**, MySQL tuner ne fournit que des recommandations. Il n'apporte aucune modification à vos fichiers de configuration automatiquement. Il appartient à l'utilisateur d'examiner les suggestions et de les mettre en œuvre au besoin.

**Question : À quelle fréquence dois-je exécuter MySQL tuner ?**

Il est recommandé d'exécuter périodiquement MySQL tuner, en particulier après des modifications importantes de votre serveur MySQL ou de sa charge de travail.

Pour des résultats optimaux, exécutez le script après que votre serveur a fonctionné pendant au moins 24 heures pour recueillir suffisamment de données de performance.

**Question : Comment interpréter les résultats de MySQL tuner ?**

MySQL tuner fournit une sortie sous forme de suggestions et d'avertissements.

Examinez chaque recommandation et envisagez de mettre en œuvre les modifications dans votre fichier de configuration MySQL (généralement « my.cnf » ou « my.ini »).

Soyez prudent lorsque vous apportez des modifications et sauvegardez toujours votre fichier de configuration avant d'apporter des modifications.

**Question : MySQL tuner peut-il endommager ma base de données ou mon serveur ?**

Bien que MySQL tuner lui-même n'apporte aucune modification à votre serveur, la mise en œuvre aveugle de ses recommandations sans en comprendre l'impact peut entraîner des problèmes.

Assurez-vous toujours de bien comprendre les implications de chaque suggestion avant de l'appliquer à votre serveur.

**Question : MySQL tuner prend-il en charge MariaDB et Percona Server ?**

Oui, MySQL tuner prend en charge MariaDB et Percona Server car ce sont des dérivés de MySQL et partagent une architecture similaire. Le script peut également analyser et fournir des recommandations pour ces systèmes.

**Question : Que dois-je faire si j'ai besoin d'aide avec MySQL tuner ou si j'ai des questions sur les recommandations ?**

Si vous avez besoin d'aide avec MySQL tuner ou si vous avez des questions sur les recommandations fournies par le script, vous pouvez consulter la documentation de MySQL tuner, demander conseil sur des forums en ligne ou consulter un expert MySQL.

Soyez prudent lorsque vous mettez en œuvre des modifications pour assurer la stabilité et les performances de votre serveur.

**Question : MySQLTuner réparera-t-il mon serveur MySQL lent ?**

**Non.** MySQLTuner est un script en lecture seule. Il n'écrira dans aucun fichier de configuration, ne modifiera l'état d'aucun démon. Il vous donnera un aperçu des performances de votre serveur et fera quelques recommandations de base pour les améliorations que vous pourrez apporter une fois qu'il aura terminé.

**Question : Puis-je licencier mon DBA maintenant ?**

**MySQLTuner ne remplacera votre DBA sous aucune forme.**

Si votre DBA prend constamment votre place de parking et vole votre déjeuner dans le réfrigérateur, vous voudrez peut-être y réfléchir - mais c'est votre décision.

Une fois que vous l'avez créé, assurez-vous qu'il appartient à votre utilisateur et que le mode du fichier est 0600. Cela devrait empêcher les regards indiscrets d'obtenir vos informations de connexion à la base de données dans des conditions normales.

**Question : J'obtiens "ERROR 1524 (HY000): Plugin 'unix_socket' is not loaded" même avec unix_socket=OFF. Comment corriger ?**

Cela se produit car le client MariaDB tente d'utiliser le plugin `unix_socket` par défaut lorsqu'aucun utilisateur/mot de passe n'est fourni.

* **Solution 1 (Recommandée) :** Utilisez un fichier `~/.my.cnf` comme décrit ci-dessus pour fournir des identifiants explicites.
* **Solution 2 :** Passez les identifiants directement : `perl mysqltuner.pl --user root --pass votre_mot_de_passe`.

**Question : Comment réactiver l'authentification `unix_socket` de manière sécurisée ?**

Si vous décidez d'utiliser `unix_socket` (qui permet à l'utilisateur `root` de l'OS de se connecter à `root` MariaDB sans mot de passe), suivez ces étapes :

1. Assurez-vous que le plugin est activé dans `/etc/my.cnf` : `unix_socket=ON` (ou supprimez `OFF`).
2. Dans MariaDB, définissez le plugin d'authentification pour l'utilisateur root :

   ```sql
   ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;
   ```

3. Vérifiez que le plugin `auth_socket` ou `unix_socket` est `ACTIVE` dans `SHOW PLUGINS`.

**Question : Existe-t-il un autre moyen de sécuriser les informations d'identification sur les dernières distributions MySQL et MariaDB ?**

Vous pouvez utiliser les utilitaires mysql_config_editor.

~~~bash
 $ mysql_config_editor set --login-path=client --user=someusername --password --host=localhost
 Enter password: ********
~~~

Après quoi, `~/.mylogin.cnf` sera créé avec l'accès approprié.

Pour obtenir des informations sur les informations d'identification stockées, utilisez la commande suivante :

```bash
$mysql_config_editor print
[client]
user = someusername
password = *****
host = localhost
```

**Question : Ça ne marche pas sur mon OS ! Qu'est-ce qui se passe ?!**

Ce genre de choses est voué à arriver. Voici les détails dont j'ai besoin de votre part pour enquêter sur le problème :

* OS et version de l'OS
* Architecture (x86, x86_64, IA64, Commodore 64)
* Version exacte de MySQL
* Où vous avez obtenu votre version de MySQL (package OS, source, etc.)
* Le texte intégral de l'erreur
* Une copie de la sortie de SHOW VARIABLES et SHOW GLOBAL STATUS (si possible)

**Question : Comment effectuer des vérifications de vulnérabilité CVE ?**

* Téléchargez vulnerabilities.csv depuis ce dépôt.
* utilisez l'option --cvefile pour effectuer des vérifications CVE

**Question : Comment utiliser mysqltuner depuis un hôte distant ?**
Merci à [@rolandomysqldba](https://dba.stackexchange.com/users/877/rolandomysqldba)

* Vous devrez toujours vous connecter comme un client mysql :

Connexion et authentification

 --host <hostname> Se connecter à un hôte distant pour effectuer des tests (par défaut : localhost)
 --socket <socket> Utiliser un socket différent pour une connexion locale
 --port <port>     Port à utiliser pour la connexion (par défaut : 3306)
 --user <username> Nom d'utilisateur à utiliser pour l'authentification
 --pass <password> Mot de passe à utiliser pour l'authentification
 --defaults-file <path> fichier de valeurs par défaut pour les informations d'identification

Étant donné que vous utilisez un hôte distant, utilisez des paramètres pour fournir des valeurs à partir du système d'exploitation

 --forcemem <size>  Quantité de RAM installée (en mégaoctets ou avec unités, ex. 15G, 1024M)
 --forceswap <size> Quantité de mémoire de pagination configurée (en mégaoctets ou avec unités)

* Vous devrez peut-être contacter votre administrateur système distant pour lui demander la quantité de RAM et de pagination dont vous disposez

Si la base de données a trop de tables, ou une très grande table, utilisez ceci :

 --skipsize           Ne pas énumérer les tables et leurs types/tailles (par défaut : activé)
                      (Recommandé pour les serveurs avec de nombreuses tables)

**Question : Puis-je installer ce projet à l'aide de homebrew sur Apple Macintosh ?**

Oui ! `brew install mysqltuner` peut être utilisé pour installer cette application à l'aide de [homebrew](https://brew.sh/) sur Apple Macintosh.

**Question : J'ai installé MySQLTuner via le gestionnaire de paquets de ma distribution Linux (apt/yum/dnf). Comment obtenir la dernière version ?**

Les distributions Linux telles qu'Ubuntu, Debian, RHEL et CentOS fournissent souvent une version plus ancienne de MySQLTuner dans leurs dépôts officiels. Par exemple, Ubuntu 22.04 fournit la version 1.7.17 alors que la dernière version publiée peut être nettement plus récente.

Il n'existe actuellement **aucun dépôt APT/YUM/DNF officiel** qui suit la dernière version de MySQLTuner. Pour obtenir la dernière version, utilisez l'une de ces méthodes :

* **Téléchargement direct (recommandé) :**

```bash
wget https://mysqltuner.pl/ -O mysqltuner.pl
wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/basic_passwords.txt -O basic_passwords.txt
wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/vulnerabilities.csv -O vulnerabilities.csv
chmod +x mysqltuner.pl
```

* **Git clone :**

```bash
git clone --depth 1 -b master https://github.com/major/MySQLTuner-perl.git
cd MySQLTuner-perl
perl mysqltuner.pl
```

* **Environnements isolés (air-gapped) :** Si votre serveur ne dispose pas d'un accès direct à Internet, téléchargez les fichiers ci-dessus sur un hôte disposant d'un accès Internet (ou via un proxy), puis transférez `mysqltuner.pl`, `basic_passwords.txt` et `vulnerabilities.csv` sur le serveur cible via `scp`, `rsync` ou toute autre méthode de transfert de fichiers.

MySQLTuner et Vagrant (Héritage)
--

> **Note :** L'environnement de test basé sur Vagrant est considéré comme héritage. Pour les tests modernes, utilisez la suite de tests basée sur Docker via `make test-it` ou `build/test_envs.sh`.

**Le fichier Vagrant** est stocké dans le sous-répertoire Vagrant.

## Configuration des environnements de test Docker

MySQLTuner inclut une infrastructure de test basée sur Docker pour la validation multi-versions :

```bash
# Créer et démarrer tous les conteneurs de test
sh build/createTestEnvs.sh

# Charger les aides d'environnement
source build/bashrc

# Se connecter à une base de données spécifique
mysql_percona80 sakila
```

**Cibles de test prises en charge** (reportez-vous à [support MariaDB](mariadb_support.md) et [support MySQL](mysql_support.md) pour la matrice de compatibilité actuelle) :

* MySQL 8.0, 8.4, 9.x
* MariaDB 10.6, 10.11, 11.4, 11.8
* Percona Server 8.0

Les contributions sont les bienvenues
--

Comment contribuer à l'aide d'une demande d'extraction ? Suivez ce guide : [Création d'une demande d'extraction](https://opensource.com/article/19/7/create-pull-request-github)

Étapes simples pour créer une demande d'extraction
--

* Forker ce projet Github
* Clonez-le sur votre système local
* Créez une nouvelle branche
* Apportez vos modifications
* Repoussez-le dans votre dépôt
* Cliquez sur le bouton Comparer et demande d'extraction
* Cliquez sur Créer une demande d'extraction pour ouvrir une nouvelle demande d'extraction
