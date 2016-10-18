MySQLTuner-perl
====
[![Stato della build - Master](https://travis-ci.org/major/MySQLTuner-perl.svg?branch=master)](https://travis-ci.org/major/MySQLTuner-perl)
[![Stato del progetto](http://opensource.box.com/badges/active.svg)](http://opensource.box.com/badges)
[![Stato del progetto](http://opensource.box.com/badges/maintenance.svg)](http://opensource.box.com/badges)
[![Tempo medio per la soluzione di problemi](http://isitmaintained.com/badge/resolution/major/MySQLTuner-perl.svg)](http://isitmaintained.com/project/major/MySQLTuner-perl "Average time to resolve an issue")
[![Percentuale di problemi non risolti](http://isitmaintained.com/badge/open/major/MySQLTuner-perl.svg)](http://isitmaintained.com/project/major/MySQLTuner-perl "Percentage of issues still open")
[![Licenza GPL](https://badges.frapsoft.com/os/gpl/gpl.png?v=103)](https://opensource.org/licenses/GPL-3.0/)

**MySQLTuner** è uno script Perl che permette di analizzare velocemente una installazione di MySQL, nonché di apportare modifiche per migliorare le prestazioni e la stabilità.  In modo coinciso sono riportati lo stato attuale delle variabili di configurazione e i dati sullo stato del sistema, corredati da suggerimenti di base per il miglioramento delle prestazioni.

**MySQLTuner** supporta, in quest'ultima versione, circa 250 indicatori per i server MySQL/MariaDB/Percona.

**MySQLTuner** è attivamente manutenuto e nuovi indicatori sono aggiunti di settimana in settimana, supportando un gran numero di configurazioni tra le quali ![Galera Cluster](http://galeracluster.com/), ![TokuDB](https://www.percona.com/software/mysql-database/percona-tokudb), ![                                                                                                                         Performance schema](https://github.com/mysql/mysql-sys), metriche relative al SO Linux, ![InnoDB](http://dev.mysql.com/doc/refman/5.7/en/innodb-storage-engine.html), ![MyISAM](http://dev.mysql.com/doc/refman/5.7/en/myisam-storage-engine.html), ![Aria](https://mariadb.com/kb/en/mariadb/aria/), ...

Maggiori dettagli sugli indicatori
![Indicators description](https://github.com/major/MySQLTuner-perl/blob/master/INTERNALS.md).


![MysqlTuner](https://github.com/major/MySQLTuner-perl/blob/master/mysqltuner.png)

MySQLTuner ha bisogno di te:
===

**MySQLTuner** ha bisogno di collaboratori per documentazione, codice e suggerimenti ..

* Problemi e suggerimenti possono essere riportati su [GitHub tracker](https://github.com/major/MySQLTuner-perl/issues).
* La guida per contribuire è disponibile in inglese: [MySQLTuner contributing guide](https://github.com/major/MySQLTuner-perl/blob/master/CONTRIBUTING.md)
* Dai un Stella a **MySQLTuner project** su [GitHub](https://github.com/major/MySQLTuner-perl)

Compatibilità:
====

* MySQL 5.7 (pieno supporto)
* MySQL 5.6 (pieno supporto)
* MySQL 5.5 (pieno supporto)
* MariaDB 10.1 (pieno supporto)
* MariaDB 10.0 (pieno supporto)
* Percona Server 5.6 (pieno supporto)
* Percona XtraDB cluster (pieno supporto)
* MySQL 3.23, 4.0, 4.1, 5.0, 5.1 (supporto parziale - versione deprecata)
* Perl 5.6 o successivi (col pacchetto [perl-doc](http://search.cpan.org/~dapm/perl-5.14.4/pod/perldoc.pod))
* Sistemi operativi basati su Unix/Linux (testato su Linux, varianti di BSD e di Solaris)
* Windows non è supportato al momento (gradito aiuto!!!!!)
* Accesso completo in lettura al server MySQL (accesso root a livello di SO raccomandato per MySQL < 5.1)
* supporto al rilevamento di vulnerabilità CVE da [https://cve.mitre.org](https://cve.mitre.org)

***ATTENZIONE***
--
È **estremamente importante** che tu capisca appieno ogni singola modifica apportata alla configurazione del server MySQL.
Qualora non capissi appieno qualche parte dell'output dello script o se non capissi quanto raccomandato **dovresti consultare** un DBA esperto o un amministratore di sistema di cui hai fiducia.
Testa **sempre** le modifiche su ambienti ad hoc e tieni sempre presente che miglioramenti in un settore potrebbero **influenzare negativamente** MySQL in altri settori.

**Seriamente - consulta la sezione FAQ che segue.**

Cosa verifica esattamente MySQLTuner ?
--
Tutti i controlli effettuati da **MySQLTuner** sono documentati in [MySQLTuner Internals](https://github.com/major/MySQLTuner-perl/blob/master/INTERNALS.md).

Download/Installazione
--

Si può semplicemente scaricare l'intero codice utilizzando `git clone` seguito dalla URL riportata sopra.
Il modo più semplice è il seguente:

	wget http://mysqltuner.pl/ -O mysqltuner.pl
	wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/basic_passwords.txt -O basic_passwords.txt
	wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/vulnerabilities.csv -O vulnerabilities.csv
	perl mysqltuner.pl

Ovviamente è possibile assegnare il permesso di esecuzione in modo da poter lanciare il comando senza chiamare l'interprete `perl` (`chmod +x mysqltuner.pl`).

Casi d'uso
--

__Uso:__ Minimale locale

	perl mysqltuner.pl

__Uso:__ Minimale da remoto

	perl mysqltuner.pl --host targetDNS_IP --user admin_user --pass admin_password

__Uso:__ Abilitando il massimo livello di informazione in output su MySQL/MariaDb senza usare l'optione di debug

	perl mysqltuner.pl --verbose
	perl mysqltuner.pl --buffers --dbstat --idxstat --sysstat --pfstat


__Uso:__ Abilitando la verifica delle vulnerabilità CVE per la versione di MariaDB o MySQL installata

	perl mysqltuner.pl --cvefile=vulnerabilities.csv

__Uso:__ Salvando i risultati su un file con le stesse informazione mostrate a video

	perl mysqltuner.pl --outputfile /tmp/result_mysqltuner.txt

__Uso:__ Salvando i risultati su un file **senza mostrare nulla a video**

	perl mysqltuner.pl --silent --outputfile /tmp/result_mysqltuner.txt

__Uso:__ Utilizzando un modello per personalizzare il file di output, con la sintassi di [Text::Template](https://metacpan.org/pod/Text::Template).

 	perl mysqltuner.pl --silent --reportfile /tmp/result_mysqltuner.txt --template=/tmp/mymodel.tmpl

__Uso:__ Abilitando la modalità di debug

	perl mysqltuner.pl --debug

FAQ
--

**Domanda: MySQLTuner sistemerà il mio server MySQL lento?**

**No.**  MySQLTuner è uno script che legge solamente.  Non scriverà alcun file di configurazione, non modificherà lo stato di alcun demone né chiamerà tua madre per augurarle buon compleanno.
Ti darà una panoramica delle prestazioni del tuo server, facendo alcune raccomandazioni basilari circa i miglioramenti che tu puoi apportare. *assicurati di leggere l'avviso precedente prima di seguire qualsiasi raccomandazione.*

**Domanda: Posso eliminare il mio DBA ora?**

**MySQLTuner non sostituirà il tuo DBA in alcun modo.** Se il tuo DBA continuamente occupa il tuo parcheggio e ruba il tuo cibo dal frigo puoi considerare l'opzione - ma resta una tua scelta.

**Domanda: Perché MySQLTuner continua a chiedermi ogni volta le credenziali di login di MySQL?**

Lo script cerca di arguirle in ogni modo possibile. Cercando file `~/.my.cnf`, file di password di Plesk e provando il login di root con password vuota.
Se nessuno di questi modi ha successo, allora la password viene richiesta. Se preferisci che lo script giri in modo automatico, senza interazione con l'utente, allora crea un file `.my.cnf` nella tua cartella home che contenga:

	[client]
	user=someusername
	pass=thatuserspassword

Una volta creato, assicurati che tu sia il proprietario (owner) e che i permessi siano 0600. Questo dovrebbe preservare le tue credenziali di login per i database da occhi indiscreti, in condizioni normali.
Se un [Terminator modello T-1000 apparisse vestito da Carabiniere](https://it.wikipedia.org/wiki/T-1000) e chiedesse le tue credenziali non avresti poi tante scelte.

**Domanda: C'è qualche altro modo per rendere sicure le credenziali sulle ultime versioni di MySQL e MariaDB ?**

Potresti utilizzare il comando `mysql_config_editor`.

	$ mysql_config_editor set --login-path=client --user=someusername --password --host=localhost
	Enter passord: ********
	$

Che crea il file `~/.mylogin.cnf` con i prmessi di accesso appropriati.

Per avere informazioni sulle credenziali salvate, si usi ilseguente comando:

	$mysql_config_editor print
	[client]
	user = someusername
	password = *****
	host = localhost

**Domanda: Quali sono i privilegi minimi, nel database, necessari per un utente *mysqltuner* ad hoc ?**

        mysql>GRANT SELECT, PROCESS,EXECUTE, REPLICATION CLIENT,SHOW DATABASES,SHOW VIEW ON *.* FOR 'mysqltuner'@'localhost' identified by pwd1234;

**Domanda: Non funziona sul mio SO! Che succede?!**

Questo genere di cose sono destinate ad accadere. Ecco i dettagli di cui ho bisogno per indagare sul problema:

* SO e versione del SO
* Architettura (x86, x86_64, IA64, Commodore 64)
* Versione esatta di MySQL
* Da dove viene la tua versione di MySQL (pacchetto del SO, sorgenti, etc.)
* Il testo completo dell'errore
* L'output dei comandi `SHOW VARIABLES;` e `SHOW GLOBAL STATUS;`(se possibile)

**Domanda: Come eseguo il check per le vulnerabilità CVE ?**

* Scarica il file `vulnerabilities.csv`da questo repository.
* Usa l'opzione `--cvefile` per eseguire i test delle CVE

**Domanda: Come uso  mysqltuner da un altro computer ?**
Grazie a [@rolandomysqldba](http://dba.stackexchange.com/users/877/rolandomysqldba)

* You will still have to connect like a mysql client:
* Ti dovrai collegare come un client mysql:

Connessione e Autenticazione

	--host <hostname> Si connette a un host remoto per eseguire i test (default: localhost)
	--socket <socket> Usa un socket per effettuare una connessione locale
	--port <port>     Porta per la connessione (default: 3306)
	--user <username> Username per l'autenticazione
	--pass <password> Password per l'autenticazione
	--defaults-file <path> defaults file per le credenziali

Poiché si sta utilizzando un host remoto, si utilizzino i seguenti parametri per fornire allo script i valori del SO

	--forcemem <size>  Valore della RAM installata, in megabyte
	--forceswap <size> Valore della memoria di swap configurata, in megabyte

* Potresti dover contattare il sistemista del server remoto per conoscere i valori di RAM e swap

Se il database ha troppe tabelle, o tabelle veramente grandi, si usi:

	--skipsize           Non elenca le tabelle ed i rispettivi tipi e dimensioni (default: on)
	                     (Raccomandato per server con molte tabelle)

MySQLTuner e Vagrant
--
**MySQLTuner** contiene le seguenti configurazioni per Vagrant:
* Fedora Core 23 / MariaDB 10.0
* Fedora Core 23 / MariaDB 10.1
* Fedora Core 23 / MySQL 5.6
* Fedora Core 23 / MySQL 5.7

**Vagrant File** sono collocati nella sotto-directory di Vagrant.
* Segui questi due passaggi dopo l'installazione di Vagrant:
	* Rinominare `VagrantFile_for_Mxxx` in `Vagrantfile`
	* `vagrant up`

**MySQLTuner** contiene una configurazione Vagrant a scopo di test e sviluppo
* Installare VirtualBox e Vagrant
	* https://www.virtualbox.org/wiki/Downloads
	* https://www.vagrantup.com/downloads.html
* Clone del repository
 	* git clone https://github.com/major/MySQLTuner-perl.git
* Installare i plugin di Vagrant `vagrant-hostmanager` e `vagrant-vbguest`
	* `vagrant plugin install vagrant-hostmanager`
	* `vagrant plugin install vagrant-vbguest`
* Aggiungere un box Fedora Core 23 dal sito ufficiale di Fedora
	* `vagrant box add --name fc23 https://download.fedoraproject.org/pub/fedora/linux/releases/23/Cloud/x86_64/Images/Fedora-Cloud-Base-Vagrant-23-20151030.x86_64.vagrant-virtualbox.box`
* Creare una directory `data`
	* `mkdir data`
* Rinominare `Vagrantfile_MariaDB10.0` in `Vagrantfile`
	* `cp MySQLTuner-perl/Vagrant/Vagrantfile_for_MariaDB10.0 Vagrantfile`
* Start vagrant
	* `vagrant up`

MySQLTuner ha bisogno di te:
--

**MySQLTuner** ha bisogno di collaboratori per documentazione, codice e suggerimenti ..

* Problemi e suggerimenti possono essere riportati su [GitHub tracker](https://github.com/major/MySQLTuner-perl/issues).
* La guida per contribuire è disponibile in inglese: [MySQLTuner contributing guide](https://github.com/major/MySQLTuner-perl/blob/master/CONTRIBUTING.md)
* Dai un Stella a **MySQLTuner project** su [GitHub](https://github.com/major/MySQLTuner-perl)

