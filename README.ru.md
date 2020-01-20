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

**MySQLTuner** поддерживает сбор показателей для множества таких конфигураций, как [Galera Cluster](http://galeracluster.com/), [TokuDB](https://www.percona.com/software/mysql-database/percona-tokudb), [Performance schema](https://github.com/mysql/mysql-sys), метрики ОС Linux, [InnoDB](http://dev.mysql.com/doc/refman/5.7/en/innodb-storage-engine.html), [MyISAM](http://dev.mysql.com/doc/refman/5.7/en/myisam-storage-engine.html), [Aria](https://mariadb.com/kb/en/mariadb/aria/), ... 


Вы можете найти больше информации об этих показателях на 
[Indicators description](https://github.com/major/MySQLTuner-perl/blob/master/INTERNALS.md).


![MysqlTuner](https://github.com/major/MySQLTuner-perl/blob/master/mysqltuner.png)

MySQLTuner нуждается в вас:
===

**MySQLTuner** нуждается в вашем вкладе в документацию и код, а так же ждёт обратную связь.

* Присоединяйтесь, пожалуйста, к нашему трекеру ошибок [GitHub tracker](https://github.com/major/MySQLTuner-perl/issues).
* Руководство по поддержке проекта доступно на [MySQLTuner contributing guide](https://github.com/major/MySQLTuner-perl/blob/master/CONTRIBUTING.md)
* Ставьте "звезды" **проекту MySQLTuner** на [MySQLTuner Git Hub Project](https://github.com/major/MySQLTuner-perl)

## Количество "звезд" по времени

[![Stargazers over time](https://starcharts.herokuapp.com/major/MySQLTuner-perl.svg)](https://starcharts.herokuapp.com/major/MySQLTuner-perl)

Совместимость
====
Результаты тестов: [Travis CI/MySQLTuner-perl](https://travis-ci.org/major/MySQLTuner-perl)
* MySQL 8   (полная поддержка, проверка пароля не работает)
* MySQL 5.7 (полная поддержка)
* MySQL 5.6 (полная поддержка)
* MySQL 5.5 (полная поддержка)
* MariaDB 10.4 (полная поддержка)
* MariaDB 10.3 (полная поддержка)
* MariaDB 10.2 (полная поддержка)
* MariaDB 10.1 (полная поддержка)
* MariaDB 10.0 (полная поддержка, последние 6 месяцeв)
* MariaDB 5.5  (полная поддержка, но без поддержки от MariaDB)
* Percona Server 8.0 (полная поддержка, проверка пароля не работает)
* Percona Server 5.7 (полная поддержка)
* Percona Server 5.6 (полная поддержка)
* Percona XtraDB cluster (частичная поддержка, нет тестового окружения)

* Mysql Replications (частичная поддержка, нет тестового окружения)
* Galera replication (частичная поддержка, нет тестового окружения)

* MySQL 3.23, 4.0, 4.1, 5.0, 5.1, 5.5 (частичная поддержка - устаревшие версии)

*** НЕ ПОДДЕРЖИВАЕМЫЕ ОКРУЖЕНИЯ - НУЖНА ПОМОЩЬ С НИМИ :) ***
* Windows не поддерживается на данное время (Необходима помощь!!!!!)
* Облачные сервисы(cloud based) не поддерживаются на данное время (Необходима помощь!!!!!)

* Поддержка детектирования CVE уязвимостей из [https://cve.mitre.org](https://cve.mitre.org)

*** МИНИМАЛЬНЫЕ ТРЕБОВАНИЯ ***

* Perl 5.6 или более поздний (с пакетом [perl-doc](http://search.cpan.org/~dapm/perl-5.14.4/pod/perldoc.pod))
* Операционная система семейства Unix/Linux (протестировано на Linux, различных вариациях BSD и Solaris)
* Неограниченный доступ на чтение для MySQL-сервера (Для работы с MySQL < 5.1 требуется root-доступ к серверу)

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

Так же **важно** подождать, что бы сервер баз данных отработал хотя бы день, для получения точных реультатов. Запуск **mysqltuner** на только что перезапущенном сервере баз данных, по факту полностью бесполезен.

**Серьезно - прочитайте раздел ЧаВо, который расположен чуть ниже.**


Рекомендации по безопасности
--

Здравствуй, пользователь directadmin!
Мы обнаружили, что запуск mysqltuner с доступами da_admin, взятыми из файла `/usr/local/directadmin/conf/my.cnf`, может привести к компрометации пароля!
Детали можно прочитать по ссылке [Issue #289](https://github.com/major/MySQLTuner-perl/issues/289).


Что именно проверяет MySQLTuner?
--
Все проверки, что выполняет **MySQLTuner**, задокументированы в [MySQLTuner Internals](https://github.com/major/MySQLTuner-perl/blob/master/INTERNALS.md)

Загрузка/Установка
--

Доступны несколько методов:
1) Прямая загрузка скрипта(самый простой и короткий метод):
```
wget http://mysqltuner.pl/ -O mysqltuner.pl
wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/basic_passwords.txt -O basic_passwords.txt
wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/vulnerabilities.csv -O vulnerabilities.csv
```

2) Вы можете скачать весь репозиторий с помощью `git clone` или `git clone --depth 1 -b master` c URL текущего репозитория.


Оциональная установка Sysschema для MySQL 5.6
--

Sysschema по умолчанию установлена на MySQL 5.7 и MySQL 8 от Oracle.
В  MySQL 5.6/5.7/8 по умолчанию performance schema включена.
Для версий старше 5.6 вы можете создать новую базу данных sys, содержащую очень полезный взгляд на Performance schema следующими командами:

	curl "https://codeload.github.com/mysql/mysql-sys/zip/master" > sysschema.zip
	# check zip file
	unzip -l sysschema.zip
	unzip sysschema.zip
	cd mysql-sys-master
	mysql -uroot -p < sys_56.sql

Опциональная установка  Performance schema и Sysschema для MariaDB 10.x
--

Sysschema не установлена по умолчанию на MariaDB 10.x.
А performance schema по умолчанию отключена в MariaDB. Для активации ее требуется включить в конфигурационном файле my.cnf:

	[mysqld]
	performance_schema = on

Вы можете создать новую базу данных sys, содержащую очень полезный взгляд на Performance schema следующими командами:

	curl "https://codeload.github.com/FromDual/mariadb-sys/zip/master" > mariadb-sys.zip
	# check zip file
	unzip -l mariadb-sys.zip
	unzip mariadb-sys.zip
	cd mariadb-sys-master/
	mysql -u root -p < ./sys_10.sql

Ошибки и их решения при установке performance schema

     ERROR at line 21: Failed to open file './tables/sys_config_data_10.sql -- ported', error: 2
     Посмотрите на #452 решение, данное @ericx

Советы по производительности
--
Обновление статистики метадаты могут очень сильно влиять на производительсноить сервера баз данных и MySQLTuner.
Убедитесь, что innodb_stats_on_metadata отключен.

    set global innodb_stats_on_metadata = 0;

Примеры использования
--

__Пример:__ Минимальный локальный запуск

	perl mysqltuner.pl --host 127.0.0.1

Конечно, вам нужно будет добавить права на выполнение скрипта (chmod +x mysqltuner.pl), если вы хотите запускать его напрямую, без указания perl.

__Пример:__ Минимальный удаленный запуск

	perl mysqltuner.pl --host targetDNS_IP --user admin_user --pass admin_password

__Пример:__ Включение максимамльного вывода информации о MySQL/MariaDb без отладочной информации

	perl mysqltuner.pl --verbose
    perl mysqltuner.pl --buffers --dbstat --idxstat --sysstat --pfstat --tbstat
	

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

__Пример:__ Обновление MySQLTuner и файлов с данными (пароль и cve), если необходимо.

    perl mysqltuner.pl --checkversion --updateversion

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
	password=thatuserspassword
	
Сразу после создания файла убедитесь, что его владельцем является ваш пользователь, а права на файл - 0600. Это защитит ваш логин и пароль от базы данных от любопытных глаз в нормальных условиях. Но у вас не будет выбора, если появится [T-1000 в униформе полицейского из Лос-Анджелеса](https://ru.wikipedia.org/wiki/T-1000) и потребует доступы от вашей базы данных.

**Вопрос: Есть ли другой способ безопасно сохранить данные для входа в последних версиях MySQL и MariaDB?**
Вы можете использовать утилиту mysql_config_editor.
~~~bash
	$ mysql_config_editor set --login-path=client --user=someusername --password --host=localhost
	Enter passord: ********
~~~
Она создаст `~/.mylogin.cnf` с корректными правами доступа.

Чтобы получить информацию о сохраненных данных для входа, выполните:

	$mysql_config_editor print
	[client]
	user = someusername
	password = *****
	host = localhost

**Вопрос: Какие минимальные привелегии нужны для специального пользователя базы данных mysqltuner?**

        mysql>GRANT SELECT, PROCESS,EXECUTE, REPLICATION CLIENT,SHOW DATABASES,SHOW VIEW ON *.* TO 'mysqltuner'@'localhost' identified by pwd1234;

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

**Вопрос: Я могу установить этот проект с помощью homebrew на Apple Macintosh?**

Да! Вы можете уставновить его командой `brew install mysqltuner` с помощью [homebrew](https://brew.sh/) на Apple Macintosh.

MySQLTuner и Vagrant
--
**MySQLTuner** содержится в следующих конфигурациях Vagrant:
* Fedora Core 10 / Docker
       
**Vagrant File** is stored in Vagrant subdirectory.
* Follow following step after vagrant installation:
    $ vagrant up

**MySQLTuner** contains a Vagrant configurations for test purpose and development
* Install VirtualBox and Vagrant
	* https://www.virtualbox.org/wiki/Downloads
	* https://www.vagrantup.com/downloads.html
* Clone repository
 	* git clone https://github.com/major/MySQLTuner-perl.git
* Install Vagrant plugins vagrant-hostmanager and  vagrant-vbguest
	* vagrant plugin install vagrant-hostmanager
	* vagrant plugin install vagrant-vbguest
* Add Fedora Core 30 box for official Fedora Download Website
	* vagrant box add --name generic/fedora30
* Create a data directory
	* mkdir data


## Настройка тестовых окружений

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

MySQLTuner нуждается в Вас:
===

**MySQLTuner** нуждается в вашем вкладе в документацию и код, а так же ждёт обратную связь.

* Присоединяйтесь, пожалуйста, к нашему трекеру ошибок [GitHub tracker](https://github.com/major/MySQLTuner-perl/issues).
* Руководство по поддержке проекта доступно на [MySQLTuner contributing guide](https://github.com/major/MySQLTuner-perl/blob/master/CONTRIBUTING.md)
* Ставьте "звезды" **проекту MySQLTuner** на [MySQLTuner Git Hub Project](https://github.com/major/MySQLTuner-perl)

