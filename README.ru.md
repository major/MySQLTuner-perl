MySQLTuner-perl
====
[![Build Status - Master](https://travis-ci.org/major/MySQLTuner-perl.svg?branch=master)](https://travis-ci.org/major/MySQLTuner-perl)
[![Project Status](http://opensource.box.com/badges/active.svg)](http://opensource.box.com/badges)
[![Project Status](http://opensource.box.com/badges/maintenance.svg)](http://opensource.box.com/badges)
[![Average time to resolve an issue](http://isitmaintained.com/badge/resolution/major/MySQLTuner-perl.svg)](http://isitmaintained.com/project/major/MySQLTuner-perl "Average time to resolve an issue")
[![Percentage of issues still open](http://isitmaintained.com/badge/open/major/MySQLTuner-perl.svg)](http://isitmaintained.com/project/major/MySQLTuner-perl "Percentage of issues still open")
[![GPL Licence](https://badges.frapsoft.com/os/gpl/gpl.png?v=103)](https://opensource.org/licenses/GPL-3.0/)

**MySQLTuner** - это скрипт, написанный на Perl, который позволяет быстро произвести осмотр текущего состояния сервера баз данных MySQL 
и составить рекомендации для увеличения производительности и стабильности работы. Выводятся текущие параметры конфигурации 
и информация о состоянии в формате отчета с основными подсказками по оптимизации.

**MySQLTuner** поддерживает порядка 300 показателей для MySQL/MariaDB/Percona Server последних версий.

**MySQLTuner** поддерживает сбор показателей для множества таких конфигураций, как ![Galera Cluster](http://galeracluster.com/), ![TokuDB](https://www.percona.com/software/mysql-database/percona-tokudb), ![                                                                                                                         Performance schema](https://github.com/mysql/mysql-sys), Linux OS metrics, ![InnoDB](http://dev.mysql.com/doc/refman/5.7/en/innodb-storage-engine.html), ![MyISAM](http://dev.mysql.com/doc/refman/5.7/en/myisam-storage-engine.html), ![Aria](https://mariadb.com/kb/en/mariadb/aria/), ... 

Вы можете найти больше информации об этих показателях на 
![Indicators description](https://github.com/major/MySQLTuner-perl/blob/master/INTERNALS.md).


![MysqlTuner](https://github.com/major/MySQLTuner-perl/blob/master/mysqltuner.png)

MySQLTuner нуждается в вас:
===

**MySQLTuner** нуждается в вашем вкладе в документацию и код, а так же ждёт обратную связь.

* Присоединяйтесь, пожалуйста, к нашему трекеру ошибок [GitHub tracker](https://github.com/major/MySQLTuner-perl/issues)</a>.
* Руководство по поддержке проекта доступно на [MySQLTuner contributing guide](https://github.com/major/MySQLTuner-perl/blob/master/CONTRIBUTING.md)
* Ставьте "звезды" **проекту MySQLTuner** на [MySQLTuner Git Hub Project](https://github.com/major/MySQLTuner-perl)

Совместимость:
====
* MySQL 5.7 (полная поддержка)
* MySQL 5.6 (полная поддержка)
* MySQL 5.5 (полная поддержка)
* MariaDB 10.1 (полная поддержка)
* MariaDB 10.0 (полная поддержка)
* Percona Server 5.6 (полнлая поддержка)
* Percona XtraDB cluster (полная поддержка)
* MySQL 3.23, 4.0, 4.1, 5.0, 5.1 (частичная поддержка - устаревшие версии)
* Perl 5.6 или более поздний (с пакетом [perl-doc](http://search.cpan.org/~dapm/perl-5.14.4/pod/perldoc.pod))
* Операционная система семейства Unix/Linux (протестировано на Linux, различных вариациях BSD и Solaris)
* Windows не поддерживается на данное время (Необходима помощь!!!!!)
* Неограниченный доступ на чтение для MySQL-сервера (Для работы с MySQL < 5.1 требуется root-доступ к серверу)
* Поддержка детектирования CVE уязвимостей из [https://cve.mitre.org](https://cve.mitre.org)

Пожалуйста, прочитайте раздел ЧаВо, который расположен чуть ниже.

***ПРЕДУПРЕЖДЕНИЕ***
--
Очень важно, чтобы вы имели представление о том, какие изменения вы 
вносите в параметры сервера баз данных MySQL. Если вы даже частично
не понимаете вывод отчета скрипта, или не понимаете рекомендации, 
которые делает скрипт, то вам лучше всего обратиться за помощью либо
к документации к серверу баз данных, либо ближайшему системному 
администратору. Всегда проверяйте ваши изменения на тестовом сервере 
и всегда будьте готовы к тому, что улучшения в одной области могут иметь
отрицательный эфект в работе MySQL в другой области.

**Серьезно - прочитайте раздел ЧаВо, который расположен чуть ниже.**

Что именно проверяет MySQLTuner?
--
Все проверки, что выполняет **MySQLTuner**, задокументированы в [MySQLTuner Internals](https://github.com/major/MySQLTuner-perl/blob/master/INTERNALS.md)

Загрузка/Установка
--

Вы можете скачать весь репозиторий с помощью 'git clone' c URL текущего репозитория.  Самый простой и короткий метод:

	wget http://mysqltuner.pl/ -O mysqltuner.pl
	wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/basic_passwords.txt -O basic_passwords.txt
	wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/vulnerabilities.csv -O vulnerabilities.csv
	perl mysqltuner.pl

Конечно, вам нужно будет добавить права на выполнение скрипта (chmod +x mysqltuner.pl), если вы хотите запускать его напрямую, без указания perl.


Примеры использования
--

__Пример:__ Минимальный локальный запуск

	perl mysqltuner.pl 

__Пример:__ Минимальный удаленный запуск

	perl mysqltuner.pl --host targetDNS_IP --user admin_user --pass admin_password

__Пример:__ Включение максимамльного вывода информации о MySQL/MariaDb без отладочной информации

	perl mysqltuner.pl --verbose
	perl mysqltuner.pl --buffers --dbstat --idxstat --sysstat --pfstat
	

__Пример:__ Включение проверки на CVE уязвимости для MariaDB или MySQL

	perl mysqltuner.pl --cvefile=vulnerabilities.csv

__Пример:__ Запись результата в файл с отображением информации

	perl mysqltuner.pl --outputfile /tmp/result_mysqltuner.txt

__Пример:__ Запись результата в файл **без вывода информации** 

	perl mysqltuner.pl --silent --outputfile /tmp/result_mysqltuner.txt

__Пример:__ Использование шаблона для кастомизации отчетов, сохраняющихся в файл на базе синтаксиса [Text::Template](https://metacpan.org/pod/Text::Template).

 	perl mysqltuner.pl --silent --reportfile /tmp/result_mysqltuner.txt --template=/tmp/mymodel.tmpl

__Пример:__ Включение вывода отладочной информации

	perl mysqltuner.pl --debug

ЧаВо
--

**Вопрос: MySQLTuner починит мой медленный MySQL сервер?**

**Нет.** MySQLTuner работает только на чтение. Он не будет записывать какие-либо конфигурационные файлы, изменять статус каких-либо демонов или звонить вашей маме, чтобы поздравить её с днём рождения. Он только даст обзор производительности вашего сервера и предложит несколько базовых рекомендаций, которые вы можете выполнить. *Убедитесь, что вы прочитали предупреждения до следования рекомендациям.*

**Вопрос: Теперь я могу уволить моего DBA?**

**MySQLTuner не заменяет вашего DBA никоим образом.** Однако, если ваш DBA постоянно занимает ваше парковочное место и крадёт ваш обед из холодильника, вы можете попробовать сделать это - но это будет ваш выбор.

**Вопрос: Почему MySQLTuner каждый раз запрашивает доступы в MySQL?**

Скрипт пытается использовать лучшие способы войти из возможных. Он проверяет ~/.my.cnf файлы, файлы паролей Plesk и пробует пустой пароль для пользователя root. Если ни один из этих способов не сработал, то запрашивается ввод пароля. Если вы хотите, чтобы скрипт работал автоматически, создайте в своей домашней директории файл .my.cnf, содержащий:  

	[client]
	user=distributions
	pass=thatuserspassword
	
Сразу после создания файла убедитесь, что его владельцем является ваш пользователь, а права на файл - 0600. Это защитит ваш логин и пароль от базы данных от любопытных глаз в нормальных условиях. Но у вас не будет выбора, если появится [T-1000 в униформе полицейского из Лос-Анджелеса](https://ru.wikipedia.org/wiki/T-1000) и потребует доступы от вашей базы данных.

**Вопрос: Есть ли другой способ безопасно сохранить данные для входа в последних версиях MySQL и MariaDB?**
Вы можете использовать утилиту mysql_config_editor.

	$ mysql_config_editor set --login-path=client --user=someusername --password --host=localhost
	Enter passord: ********
	$

Она создаст ~/.mylogin.cnf с корректными правами доступа.

Чтобы получить информацию о сохраненных данных для входа, выполните:

	$mysql_config_editor print
	[client]
	user = someusername
	password = *****
	host = localhost

**Вопрос: Какие минимальные привелегии нужны для специального пользователя базы данных mysqltuner?**

        mysql>GRANT SELECT, PROCESS,EXECUTE, REPLICATION CLIENT,SHOW DATABASES,SHOW VIEW ON *.* FOR 'mysqltuner'@'localhost' identified by pwd1234;

**Вопрос: Это не работает на моей ОС! Что делать?!**

Иногда такое случается. Чтобы тщательно исследовать проблему, необходимы следующие данные:

* ОС и версия ОС
* Архитектура (x86, x86_64, IA64, Commodore 64)
* Точная версия MySQL
* Где вы взяли данную версию MySQL(OS package, source, etc)
* Полный текст ошибки
* Копия вывода SHOW VARIABLES и SHOW GLOBAL STATUS (если это возможно)

**Вопрос: Как выполнить проверку на CVE уязвимости?**

* Скачать vulnerabilities.csv с этого репозитория.
* Использовать опцию --cvefile для проверки

**Вопрос: Как использовать mysqltuner с удалённого хоста?**
Спасибо  [@rolandomysqldba](http://dba.stackexchange.com/users/877/rolandomysqldba)

* Вы можете подключиться так же, как для обычного mysql-клиета:

Подключение и аутентификация.

	--host <hostname> Connect to a remote host to perform tests (default: localhost)
	--socket <socket> Use a different socket for a local connection
	--port <port>     Port to use for connection (default: 3306)
	--user <username> Username to use for authentication	
	--pass <password> Password to use for authentication
	--defaults-file <path> defaulfs file for credentials

Так как вы используете удалённый хост, используйте параметры для указания данных об ОС

	--forcemem <size>  Количество оперативной памяти в мегабайтах
	--forceswap <size> Количество swap памяти в мегабайтах

* Вы можете обратиться к вашему системному администратору, чтобы спросить, сколько оперативной памяти и swap'а вам доступно

Если у баз слишком много таблиц, или есть очень большие таблицы, используйте опцию

	--skipsize           Don't enumerate tables and their types/sizes (default: on)
	                     (Recommended for servers with many tables)

MySQLTuner и Vagrant
--
**MySQLTuner** содержится в следующих конфигурациях Vagrant:
* Fedora Core 23 / MariaDB 10.0
* Fedora Core 23 / MariaDB 10.1
* Fedora Core 23 / MySQL 5.6
* Fedora Core 23 / MySQL 5.7
       
**Vagrant File** are stored in Vagrant subdirectory. 
* Follow this 2 steps after vagrant installation:
* Rename VagrantFile_for_Mxxx into Vagrantfile
* vagrant up

**MySQLTuner** contains a Vagrant configurations for test purpose and development
* Install VirtualBox and Vagrant
	* https://www.virtualbox.org/wiki/Downloads
	* https://www.vagrantup.com/downloads.html
* Clone repository
 	* git clone https://github.com/major/MySQLTuner-perl.git
* Install Vagrant plugins vagrant-hostmanager and  vagrant-vbguest
	* vagrant plugin install vagrant-hostmanager
	* vagrant plugin install vagrant-vbguest
* Add Fedora Core 23 box for official Fedora Download Website
	* vagrant box add --name fc23 https://download.fedoraproject.org/pub/fedora/linux/releases/23/Cloud/x86_64/Images/Fedora-Cloud-Base-Vagrant-23-20151030.x86_64.vagrant-virtualbox.box
* Create a data directory
	* mkdir data
* Rename Vagrantfile_MariaDB10.0 into Vagrantfile
	* cp MySQLTuner-perl/Vagrant/Vagrantfile_for_MariaDB10.0 Vagrantfile
* Start vagrant
	* vagrant up

MySQLTuner нуждается в Вас:
===

**MySQLTuner** нуждается в вашем вкладе в документацию и код, а так же ждёт обратную связь.

* Присоединяйтесь, пожалуйста, к нашему трекеру ошибок [GitHub tracker](https://github.com/major/MySQLTuner-perl/issues)</a>.
* Руководство по поддержке проекта доступно на [MySQLTuner contributing guide](https://github.com/major/MySQLTuner-perl/blob/master/CONTRIBUTING.md)
* Ставьте "звезды" **проекту MySQLTuner** на [MySQLTuner Git Hub Project](https://github.com/major/MySQLTuner-perl)

