![MySQLTuner-perl](mtlogo2.png)

[!["Offrici un caffè"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/jmrenouard)

[![Stato del progetto](https://opensource.box.com/badges/active.svg)](https://opensource.box.com/badges)
[![Stato dei test](https://github.com/anuraghazra/github-readme-stats/workflows/Test/badge.svg)](https://github.com/anuraghazra/github-readme-stats/)
[![Tempo medio per risolvere un problema](https://isitmaintained.com/badge/resolution/jmrenouard/MySQLTuner-perl.svg)](https://isitmaintained.com/project/jmrenouard/MySQLTuner-perl "Tempo medio per risolvere un problema")
[![Percentuale di problemi aperti](https://isitmaintained.com/badge/open/jmrenouard/MySQLTuner-perl.svg)](https://isitmaintained.com/project/jmrenouard/MySQLTuner-perl "Percentuale di problemi ancora aperti")
[![Licenza GPL](https://badges.frapsoft.com/os/gpl/gpl.png?v=103)](https://opensource.org/licenses/GPL-3.0/)

**MySQLTuner** è uno script scritto in Perl che consente di esaminare rapidamente un'installazione di MySQL e apportare modifiche per aumentare le prestazioni e la stabilità. Le variabili di configurazione correnti e i dati di stato vengono recuperati e presentati in un formato breve insieme ad alcuni suggerimenti di base sulle prestazioni.

**MySQLTuner** supporta circa 300 indicatori per MySQL/MariaDB/Percona Server in quest'ultima versione.

**MySQLTuner** è attivamente mantenuto e supporta molte configurazioni come [Galera Cluster](https://galeracluster.com/), [TokuDB](https://www.percona.com/software/mysql-database/percona-tokudb), [Performance schema](https://github.com/mysql/mysql-sys), metriche del sistema operativo Linux, [InnoDB](https://dev.mysql.com/doc/refman/5.7/en/innodb-storage-engine.html), [MyISAM](https://dev.mysql.com/doc/refman/5.7/en/myisam-storage-engine.html), [Aria](https://mariadb.com/docs/server/server-usage/storage-engines/aria/aria-storage-engine), ...

Puoi trovare maggiori dettagli su questi indicatori qui:
[Descrizione degli indicatori](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/INTERNALS.md).

![MysqlTuner](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/mysqltuner.png)

Link Utili
==

* **Sviluppo Attivo:** [https://github.com/jmrenouard/MySQLTuner-perl](https://github.com/jmrenouard/MySQLTuner-perl)
* **Release/Tag:** [https://github.com/jmrenouard/MySQLTuner-perl/tags](https://github.com/jmrenouard/MySQLTuner-perl/tags)
* **Changelog:** [https://github.com/jmrenouard/MySQLTuner-perl/blob/master/Changelog](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/Changelog)
* **Immagini Docker:** [https://hub.docker.com/repository/docker/jmrenouard/mysqltuner/tags](https://hub.docker.com/repository/docker/jmrenouard/mysqltuner/tags)

MySQLTuner ha bisogno di te
===

**MySQLTuner** ha bisogno di contributori per la documentazione, il codice e il feedback:

* Unisciti a noi sul nostro issue tracker su [GitHub tracker](https://github.com/jmrenouard/MySQLTuner-perl/issues).
* La guida per i contributi è disponibile seguendo la [guida per i contributi di MySQLTuner](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/CONTRIBUTING.md)
* Metti una stella al **progetto MySQLTuner** su [Progetto Git Hub di MySQLTuner](https://github.com/jmrenouard/MySQLTuner-perl/)
* Supporto a pagamento per LightPath qui: [jmrenouard@lightpath.fr](jmrenouard@lightpath.fr)
* Supporto a pagamento per Releem disponibile qui: [App Releem](https://releem.com/)

![Statistiche GitHub di Anurag](https://github-readme-stats.vercel.app/api?username=anuraghazra&show_icons=true&theme=radical)

## Stargazer nel tempo

[![Stargazer nel tempo](https://starchart.cc/jmrenouard/MySQLTuner-perl.svg)](https://starchart.cc/jmrenouard/MySQLTuner-perl)

Compatibilità
====

I risultati dei test sono disponibili qui solo per LTS:

* MySQL (supporto completo)
* Percona Server (supporto completo)
* MariaDB (supporto completo)
* Replica Galera (supporto completo)
* Cluster Percona XtraDB (supporto completo)
* Replica MySQL (supporto parziale, nessun ambiente di test)

Grazie a [endoflife.date](endoflife.date)

* Fare riferimento a [Versioni supportate di MariaDB](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/mariadb_support.md).
* Fare riferimento a [Versioni supportate di MySQL](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/mysql_support.md).

***Il supporto per Windows è parziale***

* Windows è ora supportato
* Eseguito con successo MySQLtuner su WSL2 (sottosistema Windows per Linux)
* [https://docs.microsoft.com/en-us/windows/wsl/](https://docs.microsoft.com/en-us/windows/wsl/)

***AMBIENTI NON SUPPORTATI - È NECESSARIO AIUTO***

* Il cloud based non è attualmente supportato (aiuto richiesto! Supporto richiesto per GCP, AWS, Azure)

***Motori di archiviazione non supportati: le PR sono benvenute***
--

* NDB non è supportato, sentiti libero di creare una Pull Request
* Archive
* Spider
* ColummStore
* Connect

Cose non mantenute da MySQL o MariaDB
--

* MyISAM è troppo vecchio e non più attivo
* RockDB non è più mantenuto
* TokuDB non è più mantenuto
* XtraDB non è più mantenuto

* Supporto per il rilevamento delle vulnerabilità CVE da [https://cve.mitre.org](https://cve.mitre.org)

***REQUISITI MINIMI***

* Perl 5.6 o successivo (con pacchetto [perl-doc](https://metacpan.org/release/DAPM/perl-5.14.4/view/pod/perldoc.pod))
* Sistema operativo basato su Unix/Linux (testé su Linux, varianti BSD e varianti Solaris)
* Accesso in lettura illimitato al server MySQL (vedi Privilegi di seguito)

***PRIVILEGI***
--

Per eseguire MySQLTuner con tutte le funzionalità, sono richiesti i seguenti privilegi:

**MySQL 8.0+**:

```sql
GRANT SELECT, PROCESS, SHOW DATABASES, EXECUTE, REPLICATION SLAVE, REPLICATION CLIENT, SHOW VIEW ON *.* TO 'mysqltuner'@'localhost';
```

**MariaDB 10.5+**:

```sql
GRANT SELECT, PROCESS, SHOW DATABASES, EXECUTE, BINLOG MONITOR, SHOW VIEW, REPLICATION MASTER ADMIN, SLAVE MONITOR ON *.* TO 'mysqltuner'@'localhost';
```

**Versioni legacy**:

```sql
GRANT SELECT, PROCESS, EXECUTE, REPLICATION CLIENT, SHOW DATABASES, SHOW VIEW ON *.* TO 'mysqltuner'@'localhost';
```

Accesso root al sistema operativo consigliato per MySQL < 5.1

***AVVERTIMENTO***
--

È **importante** comprendere appieno ogni modifica
apportata a un server di database MySQL. Se non si comprendono porzioni
dell'output dello script o se non si comprendono le raccomandazioni,
**è necessario consultare** un DBA o un amministratore di sistema esperto
di cui ci si fida. **Testare sempre** le modifiche in ambienti di staging e
tenere sempre presente che i miglioramenti in un'area possono **influire negativamente**
su MySQL in altre aree.

È **anche importante** attendere almeno 24 ore di uptime per ottenere risultati accurati. Infatti, eseguire
**mysqltuner** su un server appena riavviato è completamente inutile.

**Rivedi anche la sezione delle domande frequenti di seguito.**

Raccomandazioni di sicurezza
--

Ciao utente di directadmin!
Abbiamo rilevato che esegui mysqltuner con le credenziali di da_admin prese da `/usr/local/directadmin/conf/my.cnf`, il che potrebbe portare alla scoperta di una password!
Leggi il link per maggiori dettagli [Problema #289](https://github.com/jmrenouard/MySQLTuner-perl/issues/289).

Cosa sta controllando esattamente MySQLTuner?
--

Tutti i controlli eseguiti da **MySQLTuner** sono documentati nella documentazione [MySQLTuner Internals](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/INTERNALS.md).

Download/Installazione
--

Scegli uno di questi metodi:

1) Download diretto dello script (il metodo più semplice e breve):

```bash
wget http://mysqltuner.pl/ -O mysqltuner.pl
wget https://raw.githubusercontent.com/jmrenouard/MySQLTuner-perl/master/basic_passwords.txt -O basic_passwords.txt
wget https://raw.githubusercontent.com/jmrenouard/MySQLTuner-perl/master/vulnerabilities.csv -O vulnerabilities.csv
```

1) È possibile scaricare l'intero repository utilizzando `git clone` o `git clone --depth 1 -b master` seguito dall'URL di clonazione sopra.

Installazione facoltativa di Sysschema per MySQL 5.6
--

Sysschema è installato per impostazione predefinita in MySQL 5.7 e MySQL 8 da Oracle.
Per impostazione predefinita, in MySQL 5.6/5.7/8, lo schema delle prestazioni è abilitato.
Per la versione precedente di MySQL 5.6, è possibile seguire questo comando per creare un nuovo database sys contenente una vista molto utile sullo schema delle prestazioni:

Sysschema per la vecchia versione di MySQL
--

```bash
curl "https://codeload.github.com/mysql/mysql-sys/zip/master" > sysschema.zip
# controlla il file zip
unzip -l sysschema.zip
unzip sysschema.zip
cd mysql-sys-master
mysql -uroot -p < sys_56.sql
```

Sysschema per la vecchia versione di MariaDB
--

```bash
curl "https://github.com/FromDual/mariadb-sys/archive/refs/heads/master.zip" > sysschema.zip
# controlla il file zip
unzip -l sysschema.zip
unzip sysschema.zip
cd mariadb-sys-master
mysql -u root -p < ./sys_10.sql
```

Impostazione dello schema delle prestazioni
--

Per impostazione predefinita, performance_schema è abilitato e sysschema è installato sull'ultima versione.

Per impostazione predefinita, su MariaDB, lo schema delle prestazioni è disabilitato (MariaDB<10.6).

Considera di attivare lo schema delle prestazioni nel tuo file di configurazione my.cnf:

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

Installazione di Sysschema per MariaDB < 10.6
--

Sysschema non è installato per impostazione predefinita in MariaDB prima della 10.6 [MariaDB sys](https://mariadb.com/kb/en/sys-schema/)

È possibile seguire questo comando per creare un nuovo database sys contenente una vista utile sullo schema delle prestazioni:

```bash
curl "https://codeload.github.com/FromDual/mariadb-sys/zip/master" > mariadb-sys.zip
# controlla il file zip
unzip -l mariadb-sys.zip
unzip mariadb-sys.zip
cd mariadb-sys-master/
mysql -u root -p < ./sys_10.sql
```

Errori e soluzioni per l'installazione dello schema delle prestazioni
--

ERRORE 1054 (42S22) alla riga 78 nel file: './views/p_s/metrics_56.sql': colonna sconosciuta 'STATUS' nell'elenco dei campi
--

Questo errore può essere tranquillamente ignorato
Considera di utilizzare una versione recente di MySQL/MariaDB per evitare questo tipo di problema durante l'installazione di sysschema

Nelle versioni recenti, sysschema è installato e integrato per impostazione predefinita come schema sys (SHOW DATABASES)

ERRORE alla riga 21: impossibile aprire il file './tables/sys_config_data_10.sql -- ported', errore: 2
Dai un'occhiata alla soluzione #452 fornita da @ericx
--

Correzione della configurazione di sysctl (/etc/sysctl.conf)

--
È un'impostazione a livello di sistema e non un'impostazione del database: [Impostazioni del kernel FS di Linux](https://www.kernel.org/doc/html/latest/admin-guide/sysctl/fs.html#id1)

È possibile controllare i suoi valori tramite:

```bash
$ cat /proc/sys/fs/aio-*
65536
2305
```

Ad esempio, per impostare il valore aio-max-nr, aggiungere la seguente riga al file /etc/sysctl.conf:

```bash
fs.aio-max-nr = 1048576
```

Per attivare la nuova impostazione:

```bash
sysctl -p /etc/sysctl.conf
```

Utilizzo specifico
--

**Utilizzo:** utilizzo minimo a livello locale

```bash
perl mysqltuner.pl --host 127.0.0.1
```

Naturalmente, è possibile aggiungere il bit di esecuzione (`chmod +x mysqltuner.pl`) in modo da poterlo eseguire senza chiamare direttamente Perl.

**Utilizzo:** utilizzo minimo da remoto

Nella versione precedente, --forcemem doveva essere impostato manualmente, per poter eseguire un'analisi di MySQLTuner

Dalla versione 2.1.10, memoria e swap sono definiti a 1 Gb per impostazione predefinita.

Se si desidera un valore più accurato in base al proprio server remoto, è possibile impostare --forcemem e --forceswap sul valore reale della RAM

```bash
perl mysqltuner.pl --host targetDNS_IP --user admin_user --pass admin_password
```

**Utilizzo:** abilita le informazioni di output massime su MySQL/MariaDb senza debug

```bash
perl mysqltuner.pl --verbose
perl mysqltuner.pl --buffers --dbstat --idxstat --sysstat --pfstat --tbstat
```

**Utilizzo:** abilita il controllo delle vulnerabilità CVE per la tua versione di MariaDB o MySQL

```bash
perl mysqltuner.pl --cvefile=vulnerabilities.csv
```

**Utilizzo:** scrivi il risultato in un file con le informazioni visualizzate

```bash
perl mysqltuner.pl --outputfile /tmp/result_mysqltuner.txt
```

**Utilizzo:** scrivi il risultato in un file **senza visualizzare le informazioni**

```bash
perl mysqltuner.pl --silent --outputfile /tmp/result_mysqltuner.txt
```

**Utilizzo:** utilizzo del modello per personalizzare il file di reporting in base alla sintassi di [Text::Template](https://metacpan.org/pod/Text::Template).

```bash
perl mysqltuner.pl --silent --reportfile /tmp/result_mysqltuner.txt --template=/tmp/mymodel.tmpl
```

**Importante**: il modulo [Text::Template](https://metacpan.org/pod/Text::Template) è obbligatorio per le opzioni `--reportfile` e/o `--template`, perché questo modulo è necessario per generare un output appropriato basato su un modello di testo.

**Utilizzo:** dump di tutte le viste information_schema e sysschema come file csv nella sottodirectory dei risultati

```bash
perl mysqltuner.pl --verbose --dumpdir=./result
```

**Utilizzo:** abilita le informazioni di debug

```bash
perl mysqltuner.pl --debug
```

**Utilizzo:** aggiorna MySQLTuner e i file di dati (password e cve) se necessario

```bash
perl mysqltuner.pl --checkversion --updateversion
```

Supporto cloud
--

MySQLTuner ora ha un supporto sperimentale per i servizi MySQL basati su cloud.

* `--cloud`: abilita la modalità cloud. Questo è un flag generico per qualsiasi provider di cloud.
* `--azure`: abilita il supporto specifico per Azure.
* `--ssh-host <hostname>`: l'host SSH per le connessioni cloud.
* `--ssh-user <username>`: l'utente SSH per le connessioni cloud.
* `--ssh-password <password>`: la password SSH per le connessioni cloud.
* `--ssh-identity-file <path>`: il percorso del file di identità SSH per le connessioni cloud.

Report HTML basati su Python Jinja2
--

La generazione di HTML si basa su Python/Jinja2

**Procedura di generazione di HTML**

* Genera il report di mysqltuner.pl utilizzando il formato JSON (--json)
* Genera il report HTML utilizzando gli strumenti j2 di Python

**I modelli Jinja2 si trovano nella sottodirectory dei modelli**

Un esempio di base si chiama basic.html.j2

**Installazione di Python j2**

```bash
python -mvenv j2
source ./j2/bin/activate
(j2) pip install j2
```

**Utilizzo della generazione di report HTML**

```bash
perl mysqltuner.pl --verbose --json > reports.json
cat reports.json  j2 -f json MySQLTuner-perl/templates/basic.html.j2 > variables.html
```

o

```bash
perl mysqltuner.pl --verbose --json | j2 -f json MySQLTuner-perl/templates/basic.html.j2 > variables.html
```

Report HTML basati su AHA
--

La generazione di HTML si basa su AHA

**Procedura di generazione di HTML**

* Genera il report di mysqltuner.pl utilizzando i report di testo standard
* Genera il report HTML utilizzando aha

**Installazione di Aha**

Segui le istruzioni dal repository di Github

[Repository principale di GitHub AHA](https://github.com/theZiz/aha)

**Utilizzo della generazione di report HTML AHA**

 perl mysqltuner.pl --verbose --color > reports.txt
 aha --black --title "MySQLTuner" -f "reports.txt" > "reports.html"

o

 perl mysqltuner.pl --verbose --color | aha --black --title "MySQLTuner" > reports.html

FAQ
--

**Domanda: quali sono i prerequisiti per l'esecuzione di MySQL tuner?**

Prima di eseguire MySQL tuner, è necessario disporre di quanto segue:

* Un'installazione del server MySQL
* Perl installato sul tuo sistema
* Accesso amministrativo al tuo server MySQL

**Domanda: MySQL tuner può apportare modifiche alla mia configurazione automaticamente?**

**No.**, MySQL tuner fornisce solo raccomandazioni. Non apporta automaticamente alcuna modifica ai file di configurazione. Spetta all'utente rivedere i suggerimenti e implementarli secondo necessità.

**Domanda: con quale frequenza devo eseguire MySQL tuner?**

Si consiglia di eseguire periodicamente MySQL tuner, soprattutto dopo modifiche significative al server MySQL o al suo carico di lavoro.

Per risultati ottimali, esegui lo script dopo che il server è stato in esecuzione per almeno 24 ore per raccogliere dati sufficienti sulle prestazioni.

**Domanda: come interpreto i risultati di MySQL tuner?**

MySQL tuner fornisce l'output sotto forma di suggerimenti e avvisi.

Rivedi ogni raccomandazione e considera di implementare le modifiche nel tuo file di configurazione di MySQL (di solito "my.cnf" o "my.ini").

Sii cauto quando apporti modifiche e esegui sempre il backup del file di configurazione prima di apportare qualsiasi modifica.

**Domanda: MySQL tuner può causare danni al mio database o server?**

Sebbene MySQL tuner stesso non apporterà alcuna modifica al tuo server, l'implementazione cieca delle sue raccomandazioni senza comprenderne l'impatto può causare problemi.

Assicurati sempre di comprendere le implicazioni di ogni suggerimento prima di applicarlo al tuo server.

**Domanda: MySQL tuner supporta MariaDB e Percona Server?**

Sì, MySQL tuner supporta MariaDB e Percona Server poiché sono derivati ​​di MySQL e condividono un'architettura simile. Lo script può analizzare e fornire raccomandazioni anche per questi sistemi.

**Domanda: cosa devo fare se ho bisogno di aiuto con MySQL tuner o ho domande sulle raccomandazioni?**

Se hai bisogno di aiuto con MySQL tuner o hai domande sulle raccomandazioni fornite dallo script, puoi consultare la documentazione di MySQL tuner, chiedere consiglio ai forum online o consultare un esperto di MySQL.

Sii cauto quando implementi le modifiche per garantire la stabilità e le prestazioni del tuo server.

**Domanda: MySQLTuner risolverà il mio server MySQL lento?**

**No.** MySQLTuner è uno script di sola lettura. Non scriverà in alcun file di configurazione, non modificherà lo stato di alcun demone. Ti darà una panoramica delle prestazioni del tuo server e formulerà alcune raccomandazioni di base per i miglioramenti che puoi apportare dopo il suo completamento.

**Domanda: posso licenziare il mio DBA ora?**

**MySQLTuner non sostituirà il tuo DBA in nessuna forma o modo.**

Se il tuo DBA prende costantemente il tuo parcheggio e ti ruba il pranzo dal frigorifero, allora potresti volerlo considerare, ma questa è una tua decisione.

Una volta creato, assicurati che sia di proprietà del tuo utente e che la modalità del file sia 0600. Ciò dovrebbe impedire agli occhi indiscrets di ottenere le credenziali di accesso al database in condizioni normali.

**Domanda: ricevo "ERROR 1524 (HY000): Plugin 'unix_socket' is not loaded" anche con unix_socket=OFF. Come risolvere?**

Ciò accade perché il client MariaDB tenta di utilizzare il plugin `unix_socket` per impostazione predefinita quando non viene fornito alcun utente/password.

* **Soluzione 1 (consigliata):** usa un file `~/.my.cnf` come descritto sopra per fornire credenziali esplicite.
* **Soluzione 2:** passa le credenziali direttamente: `perl mysqltuner.pl --user root --pass vostra_password`.

**Domanda: come riabilitare in modo sicuro l'autenticazione `unix_socket`?**

Se decidi di utilizzare `unix_socket` (che consente all'utente `root` del sistema operativo di accedere a MariaDB `root` senza password), segui questi passaggi:

1. Assicurati che il plugin sia abilitato in `/etc/my.cnf`: `unix_socket=ON` (o rimuovi `OFF`).
2. In MariaDB, imposta il plugin di autenticazione per l'utente root:

   ```sql
   ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;
   ```

3. Verifica che il plugin `auth_socket` o `unix_socket` sia `ACTIVE` in `SHOW PLUGINS`.

**Domanda: c'è un altro modo per proteggere le credenziali sulle ultime distribuzioni di MySQL e MariaDB?**

È possibile utilizzare le utilità di mysql_config_editor.

~~~bash
 $ mysql_config_editor set --login-path=client --user=someusername --password --host=localhost
 Inserisci password: ********
~~~

Successivamente, verrà creato `~/.mylogin.cnf` con l'accesso appropriato.

Per ottenere informazioni sulle credenziali archiviate, utilizzare il seguente comando:

```bash
$mysql_config_editor print
[client]
user = someusername
password = *****
host = localhost
```

**Domanda: non funziona sul mio sistema operativo! Che succede?!**

Questo genere di cose è destinato ad accadere. Ecco i dettagli di cui ho bisogno da te per indagare sul problema:

* Sistema operativo e versione del sistema operativo
* Architettura (x86, x86_64, IA64, Commodore 64)
* Versione esatta di MySQL
* Da dove hai ottenuto la tua versione di MySQL (pacchetto del sistema operativo, sorgente, ecc.)
* Il testo completo dell'errore
* Una copia dell'output di SHOW VARIABLES e SHOW GLOBAL STATUS (se possibile)

**Domanda: come eseguire i controlli delle vulnerabilità CVE?**

* Scarica vulnerabilities.csv da questo repository.
* usa l'opzione --cvefile per eseguire i controlli CVE

**Domanda: come usare mysqltuner da un host remoto?**
Grazie a [@rolandomysqldba](https://dba.stackexchange.com/users/877/rolandomysqldba)

* Dovrai comunque connetterti come un client mysql:

Connessione e autenticazione

 --host <hostname> Connettiti a un host remoto per eseguire i test (predefinito: localhost)
 --socket <socket> Usa un socket diverso per una connessione locale
 --port <port>     Porta da utilizzare per la connessione (predefinita: 3306)
 --user <username> Nome utente da utilizzare per l'autenticazione
 --pass <password> Password da utilizzare per l'autenticazione
 --defaults-file <path> file dei valori predefiniti per le credenziali

Poiché si sta utilizzando un host remoto, utilizzare i parametri per fornire i valori dal sistema operativo

 --forcemem <size>  Quantità di RAM installata in megabyte
 --forceswap <size> Quantità di memoria di swap configurata in megabyte

* Potrebbe essere necessario contattare l'amministratore di sistema remoto per chiedere quanta RAM e swap si dispone

Se il database ha troppe tabelle o tabelle molto grandi, usa questo:

 --skipsize           Non enumerare tabelle e i loro tipi/dimensioni (predefinito: on)
                      (Consigliato per server con molte tabelle)

**Domanda: posso installare questo progetto usando homebrew su Apple Macintosh?**

Sì! `brew install mysqltuner` può essere usato per installare questa applicazione usando [homebrew](https://brew.sh/) su Apple Macintosh.

MySQLTuner e Vagrant
--

**MySQLTuner** contiene le seguenti configurazioni di Vagrant:

* Fedora Core 30 / Docker

**Il file Vagrant** è archiviato nella sottodirectory Vagrant.

* Segui i seguenti passaggi dopo l'installazione di Vagrant:
    $ vagrant up

**MySQLTuner** contiene una configurazione Vagrant per scopi di test e sviluppo

* Installa VirtualBox e Vagrant
  * <https://www.virtualbox.org/wiki/Downloads>
  * <https://www.vagrantup.com/downloads.html>
* Clona il repository
  * git clone <https://github.com/jmrenouard/MySQLTuner-perl/.git>
* Installa i plugin di Vagrant vagrant-hostmanager e vagrant-vbguest
  * vagrant plugin install vagrant-hostmanager
  * vagrant plugin install vagrant-vbguest
* Aggiungi la box di Fedora Core 30 dal sito Web di download ufficiale di Fedora
  * vagrant box add --name generic/fedora30
* Crea una directory di dati
  * mkdir data

## configura ambienti di test

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

I contributi sono benvenuti
--

Come contribuire utilizzando una Pull Request? Segui questa guida: [Creazione di una pull request](https://opensource.com/article/19/7/create-pull-request-github)

Semplici passaggi per creare una pull request
--

* Esegui il fork di questo progetto Github
* Clonalo sul tuo sistema locale
* Crea un nuovo ramo
* Apporta le tue modifiche
* Esegui il push di nuovo nel tuo repository
* Fai clic sul pulsante Confronta e pull request
* Fai clic su Crea pull request per aprire una nuova pull request
