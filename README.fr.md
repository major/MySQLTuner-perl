![MySQLTuner-perl](mtlogo2.png)

[!["Offrez-nous un café"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/jmrenouard)

[![État du projet](https://opensource.box.com/badges/active.svg)](https://opensource.box.com/badges)
[![État des tests](https://github.com/anuraghazra/github-readme-stats/workflows/Test/badge.svg)](https://github.com/anuraghazra/github-readme-stats/)
[![Temps moyen de résolution d'un problème](https://isitmaintained.com/badge/resolution/jmrenouard/MySQLTuner-perl.svg)](https://isitmaintained.com/project/jmrenouard/MySQLTuner-perl "Temps moyen de résolution d'un problème")
[![Pourcentage de problèmes ouverts](https://isitmaintained.com/badge/open/jmrenouard/MySQLTuner-perl.svg)](https://isitmaintained.com/project/jmrenouard/MySQLTuner-perl "Pourcentage de problèmes encore ouverts")
[![Licence GPL](https://badges.frapsoft.com/os/gpl/gpl.png?v=103)](https://opensource.org/licenses/GPL-3.0/)

**MySQLTuner** est un script écrit en Perl qui vous permet d'examiner rapidement une installation MySQL et de faire des ajustements pour augmenter les performances et la stabilité. Les variables de configuration actuelles et les données d'état sont récupérées et présentées dans un bref format avec quelques suggestions de performances de base.

**MySQLTuner** prend en charge environ 300 indicateurs pour MySQL/MariaDB/Percona Server dans cette dernière version.

**MySQLTuner** est activement maintenu et prend en charge de nombreuses configurations telles que [Galera Cluster](https://galeracluster.com/), [TokuDB](https://www.percona.com/software/mysql-database/percona-tokudb), [Schéma de performance](https://github.com/mysql/mysql-sys), les métriques du système d'exploitation Linux, [InnoDB](https://dev.mysql.com/doc/refman/5.7/en/innodb-storage-engine.html), [MyISAM](https://dev.mysql.com/doc/refman/5.7/en/myisam-storage-engine.html), [Aria](https://mariadb.com/docs/server/server-usage/storage-engines/aria/aria-storage-engine), ...

Vous pouvez trouver plus de détails sur ces indicateurs ici :
[Description des indicateurs](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/INTERNALS.md).

![MysqlTuner](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/mysqltuner.png)

Liens utiles
==

* **Développement actif :** [https://github.com/jmrenouard/MySQLTuner-perl](https://github.com/jmrenouard/MySQLTuner-perl)
* **Versions/Tags :** [https://github.com/jmrenouard/MySQLTuner-perl/tags](https://github.com/jmrenouard/MySQLTuner-perl/tags)
* **Changelog :** [https://github.com/jmrenouard/MySQLTuner-perl/blob/master/Changelog](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/Changelog)
* **Images Docker :** [https://hub.docker.com/repository/docker/jmrenouard/mysqltuner/tags](https://hub.docker.com/repository/docker/jmrenouard/mysqltuner/tags)

MySQLTuner a besoin de vous
===

**MySQLTuner** a besoin de contributeurs pour la documentation, le code et les commentaires :

* Veuillez nous rejoindre sur notre outil de suivi des problèmes sur [le suivi GitHub](https://github.com/jmrenouard/MySQLTuner-perl/issues).
* Le guide de contribution est disponible en suivant [le guide de contribution de MySQLTuner](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/CONTRIBUTING.md)
* Mettez une étoile au **projet MySQLTuner** sur [le projet Git Hub de MySQLTuner](https://github.com/jmrenouard/MySQLTuner-perl/)
* Support payant pour LightPath ici : [jmrenouard@lightpath.fr](jmrenouard@lightpath.fr)
* Support payant pour Releem disponible ici : [Application Releem](https://releem.com/)

![Statistiques GitHub d'Anurag](https://github-readme-stats.vercel.app/api?username=anuraghazra&show_icons=true&theme=radical)

## Stargazers au fil du temps

[![Stargazers au fil du temps](https://starchart.cc/jmrenouard/MySQLTuner-perl.svg)](https://starchart.cc/jmrenouard/MySQLTuner-perl)

Compatibilité
====

Les résultats des tests sont disponibles ici uniquement pour les versions LTS :

* MySQL (prise en charge complète)
* Percona Server (prise en charge complète)
* MariaDB (prise en charge complète)
* Réplication Galera (prise en charge complète)
* Cluster Percona XtraDB (prise en charge complète)
* Réplication MySQL (prise en charge partielle, pas d'environnement de test)

Merci à [endoflife.date](endoflife.date)

* Reportez-vous aux [versions prises en charge de MariaDB](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/mariadb_support.md).
* Reportez-vous aux [versions prises en charge de MySQL](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/mysql_support.md).

***La prise en charge de Windows est partielle***

* Windows est maintenant pris en charge à ce moment
* Exécution réussie de MySQLtuner sur WSL2 (sous-système Windows pour Linux)
* [https://docs.microsoft.com/en-us/windows/wsl/](https://docs.microsoft.com/en-us/windows/wsl/)

***ENVIRONNEMENTS NON PRIS EN CHARGE - BESOIN D'AIDE POUR CELA***

* Le cloud n'est pas pris en charge pour le moment (aide souhaitée ! Prise en charge de GCP, AWS, Azure demandée)

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
* Accès en lecture illimité au serveur MySQL
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
Lisez le lien pour plus de détails [Problème n°289](https://github.com/jmrenouard/MySQLTuner-perl/issues/289).

Que vérifie exactement MySQLTuner ?
--

Toutes les vérifications effectuées par **MySQLTuner** sont documentées dans la documentation [MySQLTuner Internals](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/INTERNALS.md).

Téléchargement/Installation
--

Choisissez l'une de ces méthodes :

1) Téléchargement direct du script (la méthode la plus simple et la plus courte) :

```bash
wget http://mysqltuner.pl/ -O mysqltuner.pl
wget https://raw.githubusercontent.com/jmrenouard/MySQLTuner-perl/master/basic_passwords.txt -O basic_passwords.txt
wget https://raw.githubusercontent.com/jmrenouard/MySQLTuner-perl/master/vulnerabilities.csv -O vulnerabilities.csv
```

1) Vous pouvez télécharger l'intégralité du référentiel en utilisant `git clone` ou `git clone --depth 1 -b master` suivi de l'URL de clonage ci-dessus.

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

**Utilisation :** Utilisation d'un modèle pour personnaliser votre fichier de rapport basé sur la syntaxe [Text::Template](https://metacpan.org/pod/Text::Template).

```bash
perl mysqltuner.pl --silent --reportfile /tmp/result_mysqltuner.txt --template=/tmp/mymodel.tmpl
```

**Important** : le module [Text::Template](https://metacpan.org/pod/Text::Template) est obligatoire pour les options `--reportfile` et/ou `--template`, car ce module est nécessaire pour générer une sortie appropriée basée sur un modèle de texte.

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

Prise en charge du cloud
--

MySQLTuner dispose désormais d'une prise en charge expérimentale des services MySQL basés sur le cloud.

* `--cloud` : activez le mode cloud. Il s'agit d'un indicateur générique pour tout fournisseur de cloud.
* `--azure` : activez la prise en charge spécifique à Azure.
* `--ssh-host <hostname>` : l'hôte SSH pour les connexions cloud.
* `--ssh-user <username>` : l'utilisateur SSH pour les connexions cloud.
* `--ssh-password <password>` : le mot de passe SSH pour les connexions cloud.
* `--ssh-identity-file <path>` : le chemin d'accès au fichier d'identité SSH pour les connexions cloud.

Rapports HTML basés sur Python Jinja2
--

La génération de HTML est basée sur Python/Jinja2

**Procédure de génération de HTML**

* Générer le rapport mysqltuner.pl au format JSON (--json)
* Générer un rapport HTML à l'aide des outils Python j2

**Les modèles Jinja2 se trouvent dans le sous-répertoire des modèles**

Un exemple de base s'appelle basic.html.j2

**Installation de Python j2**

```bash
python -mvenv j2
source ./j2/bin/activate
(j2) pip install j2
```

**Utilisation de la génération de rapports HTML**

```bash
perl mysqltuner.pl --verbose --json > reports.json
cat reports.json  j2 -f json MySQLTuner-perl/templates/basic.html.j2 > variables.html
```

ou

```bash
perl mysqltuner.pl --verbose --json | j2 -f json MySQLTuner-perl/templates/basic.html.j2 > variables.html
```

Rapports HTML basés sur AHA
--

La génération de HTML est basée sur AHA

**Procédure de génération de HTML**

* Générer le rapport mysqltuner.pl à l'aide de rapports texte standard
* Générer un rapport HTML à l'aide d'aha

**Installation d'Aha**

Suivez les instructions du dépôt Github

[Dépôt principal de GitHub AHA](https://github.com/theZiz/aha)

**Utilisation de la génération de rapports HTML AHA**

 perl mysqltuner.pl --verbose --color > reports.txt
 aha --black --title "MySQLTuner" -f "reports.txt" > "reports.html"

ou

 perl mysqltuner.pl --verbose --color | aha --black --title "MySQLTuner" > reports.html

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

**Question : Quels sont les privilèges minimums nécessaires à un utilisateur mysqltuner spécifique dans la base de données ?**

```bash
 mysql>GRANT SELECT, PROCESS,EXECUTE, REPLICATION CLIENT,
 SHOW DATABASES,SHOW VIEW
 ON *.*
 TO 'mysqltuner'@'localhost' identified by pwd1234;
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

 --forcemem <size>  Quantité de RAM installée en mégaoctets
 --forceswap <size> Quantité de mémoire de pagination configurée en mégaoctets

* Vous devrez peut-être contacter votre administrateur système distant pour lui demander la quantité de RAM et de pagination dont vous disposez

Si la base de données a trop de tables, ou une très grande table, utilisez ceci :

 --skipsize           Ne pas énumérer les tables et leurs types/tailles (par défaut : activé)
                      (Recommandé pour les serveurs avec de nombreuses tables)

**Question : Puis-je installer ce projet à l'aide de homebrew sur Apple Macintosh ?**

Oui ! `brew install mysqltuner` peut être utilisé pour installer cette application à l'aide de [homebrew](https://brew.sh/) sur Apple Macintosh.

MySQLTuner et Vagrant
--

**MySQLTuner** contient les configurations Vagrant suivantes :

* Fedora Core 30 / Docker

**Le fichier Vagrant** est stocké dans le sous-répertoire Vagrant.

* Suivez les étapes suivantes après l'installation de Vagrant :
    $ vagrant up

**MySQLTuner** contient une configuration Vagrant à des fins de test et de développement

* Installez VirtualBox et Vagrant
  * <https://www.virtualbox.org/wiki/Downloads>
  * <https://www.vagrantup.com/downloads.html>
* Clonez le dépôt
  * git clone <https://github.com/jmrenouard/MySQLTuner-perl/.git>
* Installez les plugins Vagrant vagrant-hostmanager et vagrant-vbguest
  * vagrant plugin install vagrant-hostmanager
  * vagrant plugin install vagrant-vbguest
* Ajoutez la boîte Fedora Core 30 depuis le site de téléchargement officiel de Fedora
  * vagrant box add --name generic/fedora30
* Créez un répertoire de données
  * mkdir data

## configurer les environnements de test

    $ sh build/createTestEnvs.sh

    $ source build/bashrc
    $ mysql_percona80 sakila
    sakila> ...

    $ docker images
    mariadb                  10.1                fc612450e1f1        12 days ago         352MB
    mariadb                  10.2                027b7c57b8c6        12 days ago         340MB
    mariadb                  10.3                47dff68107c4        12 days ago         343MB
    mariadb                  10.4                92495405fc36        12 days ago         356MB
    mysql                    5.6                 95e0fc47b096        2 weeks ago         257MB
    mysql                    5.7                 383867b75fd2        2 weeks ago         373MB
    mysql                    8.0                 b8fd9553f1f0        2 weeks ago         445MB
    percona/percona-server   5.7                 ddd245ed3496        5 weeks ago         585MB
    percona/percona-server   5.6                 ed0a36e0cf1b        6 weeks ago         421MB
    percona/percona-server   8.0                 390ae97d57c6        6 weeks ago         697MB
    mariadb                  5.5                 c7bf316a4325        4 months ago        352MB
    mariadb                  10.0                d1bde56970c6        4 months ago        353MB
    mysql                    5.5                 d404d78aa797        4 months ago        205MB

    $ docker ps
    CONTAINER ID        IMAGE                        COMMAND                  CREATED             STATUS              PORTS                               NAMES
    da2be9b050c9        mariadb:5.5                  "docker-entrypoint.s…"   7 hours ago         Up 7 hours          0.0.0.0:5311->3306/tcp              mariadb55
    5deca25d5ac8        mariadb:10.0                 "docker-entrypoint.s…"   7 hours ago         Up 7 hours          0.0.0.0:5310->3306/tcp              mariadb100
    73aaeb37e2c2        mariadb:10.1                 "docker-entrypoint.s…"   7 hours ago         Up 7 hours          0.0.0.0:5309->3306/tcp              mariadb101
    72ffa77e01ec        mariadb:10.2                 "docker-entrypoint.s…"   7 hours ago         Up 7 hours          0.0.0.0:5308->3306/tcp              mariadb102
    f5996f2041df        mariadb:10.3                 "docker-entrypoint.s…"   7 hours ago         Up 7 hours          0.0.0.0:5307->3306/tcp              mariadb103
    4890c52372bb        mariadb:10.4                 "docker-entrypoint.s…"   7 hours ago         Up 7 hours          0.0.0.0:5306->3306/tcp              mariadb104
    6b9dc078e921        percona/percona-server:5.6   "/docker-entrypoint.…"   7 hours ago         Up 7 hours          0.0.0.0:4308->3306/tcp              percona56
    3a4c7c826d4c        percona/percona-server:5.7   "/docker-entrypoint.…"   7 hours ago         Up 7 hours          0.0.0.0:4307->3306/tcp              percona57
    3dda408c91b0        percona/percona-server:8.0   "/docker-entrypoint.…"   7 hours ago         Up 7 hours          33060/tcp, 0.0.0.0:4306->3306/tcp   percona80
    600a4e7e9dcd        mysql:5.5                    "docker-entrypoint.s…"   7 hours ago         Up 7 hours          0.0.0.0:3309->3306/tcp              mysql55
    4bbe54342e5d        mysql:5.6                    "docker-entrypoint.s…"   7 hours ago         Up 7 hours          0.0.0.0:3308->3306/tcp              mysql56
    a49783249a11        mysql:5.7                    "docker-entrypoint.s…"   7 hours ago         Up 7 hours          33060/tcp, 0.0.0.0:3307->3306/tcp   mysql57
    d985820667c2        mysql:8.0                    "docker-entrypoint.s…"   7 hours ago         Up 7 hours          0.0.0.0:3306->3306/tcp, 33060/tcp   mysql 8    0

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
