![MySQLTuner-perl](mtlogo2.png)

[!["Купите нам кофе"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/jmrenouard)

[![Статус проекта](https://opensource.box.com/badges/active.svg)](https://opensource.box.com/badges)
[![Статус тестов](https://github.com/anuraghazra/github-readme-stats/workflows/Test/badge.svg)](https://github.com/anuraghazra/github-readme-stats/)
[![Среднее время решения проблемы](https://isitmaintained.com/badge/resolution/jmrenouard/MySQLTuner-perl.svg)](https://isitmaintained.com/project/jmrenouard/MySQLTuner-perl "Среднее время решения проблемы")
[![Процент открытых проблем](https://isitmaintained.com/badge/open/jmrenouard/MySQLTuner-perl.svg)](https://isitmaintained.com/project/jmrenouard/MySQLTuner-perl "Процент все еще открытых проблем")
[![Лицензия GPL](https://badges.frapsoft.com/os/gpl/gpl.png?v=103)](https://opensource.org/licenses/GPL-3.0/)

**MySQLTuner** — это скрипт, написанный на Perl, который позволяет быстро просмотреть установку MySQL и внести коррективы для повышения производительности и стабильности. Текущие переменные конфигурации и данные о состоянии извлекаются и представляются в кратком формате вместе с некоторыми основными предложениями по производительности.

**MySQLTuner** поддерживает около 300 индикаторов для MySQL/MariaDB/Percona Server в этой последней версии.

**MySQLTuner** активно поддерживается и поддерживает множество конфигураций, таких как [кластер Galera](https://galeracluster.com/), [TokuDB](https://www.percona.com/software/mysql-database/percona-tokudb), [схема производительности](https://github.com/mysql/mysql-sys), метрики ОС Linux, [InnoDB](https://dev.mysql.com/doc/refman/5.7/en/innodb-storage-engine.html), [MyISAM](https://dev.mysql.com/doc/refman/5.7/en/myisam-storage-engine.html), [Aria](https://mariadb.com/docs/server/server-usage/storage-engines/aria/aria-storage-engine), ...

Более подробную информацию об этих индикаторах можно найти здесь:
[Описание индикаторов](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/INTERNALS.md).

![MysqlTuner](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/mysqltuner.png)

Полезные ссылки
==

* **Активная разработка:** [https://github.com/jmrenouard/MySQLTuner-perl](https://github.com/jmrenouard/MySQLTuner-perl)
* **Релизы/Теги:** [https://github.com/jmrenouard/MySQLTuner-perl/tags](https://github.com/jmrenouard/MySQLTuner-perl/tags)
* **Changelog:** [https://github.com/jmrenouard/MySQLTuner-perl/blob/master/Changelog](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/Changelog)
* **Docker-образы:** [https://hub.docker.com/repository/docker/jmrenouard/mysqltuner/tags](https://hub.docker.com/repository/docker/jmrenouard/mysqltuner/tags)

MySQLTuner нуждается в вас
===

**MySQLTuner** нуждается в участниках для документации, кода и обратной связи:

* Присоединяйтесь к нам в нашем трекере проблем на [трекере GitHub](https://github.com/jmrenouard/MySQLTuner-perl/issues).
* Руководство по участию доступно по следующей [руководству по участию в MySQLTuner](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/CONTRIBUTING.md)
* Отметьте звездочкой **проект MySQLTuner** на [проекте MySQLTuner на Git Hub](https://github.com/jmrenouard/MySQLTuner-perl/)
* Платная поддержка LightPath здесь: [jmrenouard@lightpath.fr](jmrenouard@lightpath.fr)
* Платная поддержка Releem доступна здесь: [приложение Releem](https://releem.com/)

![Статистика GitHub Анурага](https://github-readme-stats.vercel.app/api?username=anuraghazra&show_icons=true&theme=radical)

## Звездочеты с течением времени

[![Звездочеты с течением времени](https://starchart.cc/jmrenouard/MySQLTuner-perl.svg)](https://starchart.cc/jmrenouard/MySQLTuner-perl)

Совместимость
====

Результаты тестов доступны здесь только для LTS:

* MySQL (полная поддержка)
* Percona Server (полная поддержка)
* MariaDB (полная поддержка)
* Репликация Galera (полная поддержка)
* Кластер Percona XtraDB (полная поддержка)
* Репликация MySQL (частичная поддержка, нет тестовой среды)

Спасибо [endoflife.date](https://endoflife.date)

* См. [Поддерживаемые версии MariaDB](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/mariadb_support.md).
* См. [Поддерживаемые версии MySQL](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/mysql_support.md).

***Поддержка Windows частична***

* Windows теперь поддерживается
* Успешно запущен MySQLtuner в WSL2 (подсистема Windows для Linux)
* [https://docs.microsoft.com/en-us/windows/wsl/](https://docs.microsoft.com/en-us/windows/wsl/)

***НЕПОДДЕРЖИВАЕМЫЕ СРЕДЫ - НУЖНА ПОМОЩЬ***

* Облачные решения в настоящее время не поддерживаются (требуется помощь! Запрошена поддержка GCP, AWS, Azure)

***Неподдерживаемые механизмы хранения: приветствуются PR***
--

* NDB не поддерживается, не стесняйтесь создавать запрос на включение
* Архив
* Паук
* ColummStore
* Подключить

Неподдерживаемые вещи из MySQL или MariaDB
--

* MyISAM слишком стар и больше не активен
* RockDB больше не поддерживается
* TokuDB больше не поддерживается
* XtraDB больше не поддерживается

* Поддержка обнаружения уязвимостей CVE от [https://cve.mitre.org](https://cve.mitre.org)

***МИНИМАЛЬНЫЕ ТРЕБОВАНИЯ***

* Perl 5.6 или новее (с пакетом [perl-doc](https://metacpan.org/release/DAPM/perl-5.14.4/view/pod/perldoc.pod))
* Операционная система на базе Unix/Linux (протестировано на Linux, вариантах BSD и вариантах Solaris)
* Неограниченный доступ на чтение к серверу MySQL
Рекомендуется доступ root к ОС для MySQL < 5.1

***ПРЕДУПРЕЖДЕНИЕ***
--

**Важно**, чтобы вы полностью понимали каждое изменение
, которое вы вносите в сервер базы данных MySQL. Если вы не понимаете части
выходных данных скрипта или если вы не понимаете рекомендации,
**вам следует проконсультироваться** с осведомленным администратором баз данных или системным администратором
, которому вы доверяете. **Всегда** тестируйте свои изменения в промежуточных средах и
всегда помните, что улучшения в одной области могут **неблагоприятно повлиять**
на MySQL в других областях.

**Также важно** подождать не менее 24 часов безотказной работы, чтобы получить точные результаты. Фактически, запуск
**mysqltuner** на только что перезапущенном сервере совершенно бесполезен.

**Также ознакомьтесь с разделом часто задаваемых вопросов ниже.**

Рекомендации по безопасности
--

Привет, пользователь directadmin!
Мы обнаружили, что вы запускаете mysqltuner с учетными данными da_admin, взятыми из `/usr/local/directadmin/conf/my.cnf`, что может привести к раскрытию пароля!
Подробнее читайте по ссылке [Проблема №289](https://github.com/jmrenouard/MySQLTuner-perl/issues/289).

Что именно проверяет MySQLTuner?
--

Все проверки, выполняемые **MySQLTuner**, задокументированы в документации [MySQLTuner Internals](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/INTERNALS.md).

Скачивание/установка
--

Выберите один из этих методов:

1) Прямая загрузка скрипта (самый простой и короткий метод):

```bash
wget http://mysqltuner.pl/ -O mysqltuner.pl
wget https://raw.githubusercontent.com/jmrenouard/MySQLTuner-perl/master/basic_passwords.txt -O basic_passwords.txt
wget https://raw.githubusercontent.com/jmrenouard/MySQLTuner-perl/master/vulnerabilities.csv -O vulnerabilities.csv
```

1) Вы можете загрузить весь репозиторий, используя `git clone` или `git clone --depth 1 -b master`, за которым следует URL-адрес клонирования выше.

Необязательная установка Sysschema для MySQL 5.6
--

Sysschema устанавливается по умолчанию в MySQL 5.7 и MySQL 8 от Oracle.
По умолчанию в MySQL 5.6/5.7/8 схема производительности включена.
Для предыдущей версии MySQL 5.6 вы можете выполнить следующую команду, чтобы создать новую базу данных sys, содержащую очень полезное представление о схеме производительности:

Sysschema для старой версии MySQL
--

```bash
curl "https://codeload.github.com/mysql/mysql-sys/zip/master" > sysschema.zip
# проверьте zip-файл
unzip -l sysschema.zip
unzip sysschema.zip
cd mysql-sys-master
mysql -uroot -p < sys_56.sql
```

Sysschema для старой версии MariaDB
--

```bash
curl "https://github.com/FromDual/mariadb-sys/archive/refs/heads/master.zip" > sysschema.zip
# проверьте zip-файл
unzip -l sysschema.zip
unzip sysschema.zip
cd mariadb-sys-master
mysql -u root -p < ./sys_10.sql
```

Настройка схемы производительности
--

По умолчанию performance_schema включен, а sysschema установлен в последней версии.

По умолчанию в MariaDB схема производительности отключена (MariaDB<10.6).

Рассмотрите возможность активации схемы производительности в вашем файле конфигурации my.cnf:

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

Установка Sysschema для MariaDB < 10.6
--

Sysschema не устанавливается по умолчанию в MariaDB до версии 10.6 [MariaDB sys](https://mariadb.com/kb/en/sys-schema/)

Вы можете выполнить следующую команду, чтобы создать новую базу данных sys, содержащую полезное представление о схеме производительности:

```bash
curl "https://codeload.github.com/FromDual/mariadb-sys/zip/master" > mariadb-sys.zip
# проверьте zip-файл
unzip -l mariadb-sys.zip
unzip mariadb-sys.zip
cd mariadb-sys-master/
mysql -u root -p < ./sys_10.sql
```

Ошибки и решения для установки схемы производительности
--

ОШИБКА 1054 (42S22) в строке 78 в файле: './views/p_s/metrics_56.sql': неизвестный столбец 'STATUS' в списке полей
--

Эту ошибку можно смело игнорировать
Рассмотрите возможность использования последней версии MySQL/MariaDB, чтобы избежать подобных проблем во время установки sysschema

В последних версиях sysschema устанавливается и интегрируется по умолчанию как схема sys (SHOW DATABASES)

ОШИБКА в строке 21: не удалось открыть файл './tables/sys_config_data_10.sql -- ported', ошибка: 2
Посмотрите на решение #452, предложенное @ericx
--

Исправление конфигурации sysctl (/etc/sysctl.conf)

--
Это общесистемная настройка, а не настройка базы данных: [Настройки ядра FS Linux](https://www.kernel.org/doc/html/latest/admin-guide/sysctl/fs.html#id1)

Вы можете проверить его значения с помощью:

```bash
$ cat /proc/sys/fs/aio-*
65536
2305
```

Например, чтобы установить значение aio-max-nr, добавьте следующую строку в файл /etc/sysctl.conf:

```bash
fs.aio-max-nr = 1048576
```

Чтобы активировать новую настройку:

```bash
sysctl -p /etc/sysctl.conf
```

Специфическое использование
--

**Использование:** минимальное использование локально

```bash
perl mysqltuner.pl --host 127.0.0.1
```

Конечно, вы можете добавить бит выполнения (`chmod +x mysqltuner.pl`), чтобы вы могли выполнять его, не вызывая Perl напрямую.

**Использование:** минимальное использование удаленно

В предыдущей версии --forcemem следовало устанавливать вручную, чтобы иметь возможность запускать анализ MySQLTuner

Начиная с версии 2.1.10, память и подкачка по умолчанию определены как 1 Гб.

Если вы хотите получить более точное значение в соответствии с вашим удаленным сервером, не стесняйтесь устанавливать --forcemem и --forceswap в реальное значение ОЗУ

```bash
perl mysqltuner.pl --host targetDNS_IP --user admin_user --pass admin_password
```

**Использование:** включить максимальный вывод информации о MySQL/MariaDb без отладки

```bash
perl mysqltuner.pl --verbose
perl mysqltuner.pl --buffers --dbstat --idxstat --sysstat --pfstat --tbstat
```

**Использование:** включить проверку уязвимостей CVE для вашей версии MariaDB или MySQL

```bash
perl mysqltuner.pl --cvefile=vulnerabilities.csv
```

**Использование:** записать результат в файл с отображаемой информацией

```bash
perl mysqltuner.pl --outputfile /tmp/result_mysqltuner.txt
```

**Использование:** записать результат в файл **без вывода информации**

```bash
perl mysqltuner.pl --silent --outputfile /tmp/result_mysqltuner.txt
```

**Использование:** использование шаблона для настройки файла отчета на основе синтаксиса [Text::Template](https://metacpan.org/pod/Text::Template).

```bash
perl mysqltuner.pl --silent --reportfile /tmp/result_mysqltuner.txt --template=/tmp/mymodel.tmpl
```

**Важно**: модуль [Text::Template](https://metacpan.org/pod/Text::Template) является обязательным для опций `--reportfile` и/или `--template`, поскольку этот модуль необходим для создания соответствующего вывода на основе текстового шаблона.

**Использование:** выгрузка всех представлений information_schema и sysschema в виде файла csv в подкаталог results

```bash
perl mysqltuner.pl --verbose --dumpdir=./result
```

**Использование:** включить отладочную информацию

```bash
perl mysqltuner.pl --debug
```

**Использование:** обновить MySQLTuner и файлы данных (пароль и cve) при необходимости

```bash
perl mysqltuner.pl --checkversion --updateversion
```

Поддержка облака
--

MySQLTuner теперь имеет экспериментальную поддержку облачных сервисов MySQL.

* `--cloud`: включить облачный режим. Это общий флаг для любого облачного провайдера.
* `--azure`: включить специальную поддержку Azure.
* `--ssh-host <hostname>`: хост SSH для облачных подключений.
* `--ssh-user <username>`: пользователь SSH для облачных подключений.
* `--ssh-password <password>`: пароль SSH для облачных подключений.
* `--ssh-identity-file <path>`: путь к файлу идентификации SSH для облачных подключений.

Отчеты в формате HTML на основе Python Jinja2
--

Генерация HTML основана на Python/Jinja2

**Процедура генерации HTML**

* Сгенерируйте отчет mysqltuner.pl в формате JSON (--json)
* Сгенерируйте отчет в формате HTML с помощью инструментов Python j2

**Шаблоны Jinja2 находятся в подкаталоге templates**

Базовый пример называется basic.html.j2

**Установка Python j2**

```bash
python -mvenv j2
source ./j2/bin/activate
(j2) pip install j2
```

**Использование генерации отчетов в формате HTML**

```bash
perl mysqltuner.pl --verbose --json > reports.json
cat reports.json  j2 -f json MySQLTuner-perl/templates/basic.html.j2 > variables.html
```

или

```bash
perl mysqltuner.pl --verbose --json | j2 -f json MySQLTuner-perl/templates/basic.html.j2 > variables.html
```

Отчеты в формате HTML на основе AHA
--

Генерация HTML основана на AHA

**Процедура генерации HTML**

* Сгенерируйте отчет mysqltuner.pl, используя стандартные текстовые отчеты
* Сгенерируйте отчет в формате HTML с помощью aha

**Установка Aha**

Следуйте инструкциям из репозитория Github

[Основной репозиторий GitHub AHA](https://github.com/theZiz/aha)

**Использование генерации отчетов в формате HTML AHA**

 perl mysqltuner.pl --verbose --color > reports.txt
 aha --black --title "MySQLTuner" -f "reports.txt" > "reports.html"

или

 perl mysqltuner.pl --verbose --color | aha --black --title "MySQLTuner" > reports.html

Часто задаваемые вопросы
--

**Вопрос: каковы предварительные условия для запуска MySQL tuner?**

Перед запуском MySQL tuner у вас должно быть следующее:

* Установка сервера MySQL
* Perl, установленный в вашей системе
* Административный доступ к вашему серверу MySQL

**Вопрос: может ли MySQL tuner автоматически вносить изменения в мою конфигурацию?**

**Нет.**, MySQL tuner предоставляет только рекомендации. Он не вносит никаких изменений в ваши файлы конфигурации автоматически. Пользователь должен просмотреть предложения и реализовать их по мере необходимости.

**Вопрос: как часто я должен запускать MySQL tuner?**

Рекомендуется периодически запускать MySQL tuner, особенно после значительных изменений на вашем сервере MySQL или его рабочей нагрузки.

Для получения оптимальных результатов запускайте скрипт после того, как ваш сервер проработает не менее 24 часов, чтобы собрать достаточные данные о производительности.

**Вопрос: как мне интерпретировать результаты MySQL tuner?**

MySQL tuner предоставляет вывод в виде предложений и предупреждений.

Просмотрите каждую рекомендацию и рассмотрите возможность внесения изменений в свой файл конфигурации MySQL (обычно "my.cnf" или "my.ini").

Будьте осторожны при внесении изменений и всегда создавайте резервную копию файла конфигурации перед внесением каких-либо изменений.

**Вопрос: может ли MySQL tuner нанести вред моей базе данных или серверу?**

Хотя сам MySQL tuner не будет вносить никаких изменений в ваш сервер, слепое выполнение его рекомендаций без понимания последствий может вызвать проблемы.

Всегда убедитесь, что вы понимаете последствия каждого предложения, прежде чем применять его к своему серверу.

**Вопрос: могу ли я использовать MySQL tuner для оптимизации других систем баз данных, таких как PostgreSQL или SQL Server?**

MySQL tuner специально разработан для серверов MySQL.
Для оптимизации других систем баз данных вам потребуется использовать инструменты, разработанные для этих систем, такие как pgTune для PostgreSQL или встроенные инструменты производительности SQL Server.

**Вопрос: поддерживает ли MySQL tuner MariaDB и Percona Server?**

Да, MySQL tuner поддерживает MariaDB и Percona Server, поскольку они являются производными от MySQL и имеют схожую архитектуру. Скрипт может анализировать и предоставлять рекомендации и для этих систем.

**Вопрос: что мне делать, если мне нужна помощь с MySQL tuner или у меня есть вопросы по поводу рекомендаций?**

Если вам нужна помощь с MySQL tuner или у вас есть вопросы по поводу рекомендаций, предоставленных скриптом, вы можете обратиться к документации MySQL tuner, попросить совета на онлайн-форумах или проконсультироваться с экспертом по MySQL.

Будьте осторожны при внесении изменений, чтобы обеспечить стабильность и производительность вашего сервера.

**Вопрос: исправит ли MySQLTuner мой медленный сервер MySQL?**

**Нет.** MySQLTuner — это скрипт только для чтения. Он не будет записывать какие-либо файлы конфигурации, изменять статус каких-либо демонов. Он предоставит вам обзор производительности вашего сервера и даст несколько основных рекомендаций по улучшениям, которые вы можете внести после его завершения.

**Вопрос: могу ли я теперь уволить своего администратора баз данных?**

**MySQLTuner ни в какой форме не заменит вашего администратора баз данных.**

Если ваш администратор баз данных постоянно занимает ваше парковочное место и крадет ваш обед из холодильника, то вы можете рассмотреть этот вариант, но это ваше решение.

**Вопрос: почему MySQLTuner постоянно запрашивает у меня учетные данные для входа в MySQL?**

Скрипт сделает все возможное, чтобы войти в систему любым возможным способом. Он проверит наличие файлов ~/.my.cnf, файлов паролей Plesk и входов root с пустым паролем. Если ни один из них недоступен, вам будет предложено ввести пароль. Если вы хотите, чтобы скрипт запускался в автоматическом режиме без вмешательства пользователя, создайте файл .my.cnf в своем домашнем каталоге, который содержит:

 [client]
 user=someusername
 password=thatuserspassword

После того, как вы его создадите, убедитесь, что он принадлежит вашему пользователю, а режим файла — 0600. Это должно предотвратить подглядывание за вашими учетными данными для входа в базу данных в обычных условиях.

**Вопрос: есть ли другой способ защитить учетные данные в последних дистрибутивах MySQL и MariaDB?**

Вы можете использовать утилиты mysql_config_editor.

~~~bash
 $ mysql_config_editor set --login-path=client --user=someusername --password --host=localhost
 Введите пароль: ********
~~~

После чего будет создан `~/.mylogin.cnf` с соответствующим доступом.

Чтобы получить информацию о сохраненных учетных данных, используйте следующую команду:

```bash
$mysql_config_editor print
[client]
user = someusername
password = *****
host = localhost
```

**Вопрос: какие минимальные привилегии необходимы конкретному пользователю mysqltuner в базе данных?**

```bash
 mysql>GRANT SELECT, PROCESS,EXECUTE, REPLICATION CLIENT,
 SHOW DATABASES,SHOW VIEW
 ON *.*
 TO 'mysqltuner'@'localhost' identified by pwd1234;
```

**Вопрос: это не работает в моей ОС! В чем дело?!**

Такие вещи обязательно случаются. Вот подробности, которые мне нужны от вас для расследования проблемы:

* ОС и версия ОС
* Архитектура (x86, x86_64, IA64, Commodore 64)
* Точная версия MySQL
* Откуда вы получили свою версию MySQL (пакет ОС, исходный код и т. д.)
* Полный текст ошибки
* Копия вывода SHOW VARIABLES и SHOW GLOBAL STATUS (если возможно)

**Вопрос: как выполнять проверки уязвимостей CVE?**

* Загрузите vulnerabilities.csv из этого репозитория.
* используйте опцию --cvefile для выполнения проверок CVE

**Вопрос: как использовать mysqltuner с удаленного хоста?**
Спасибо [@rolandomysqldba](https://dba.stackexchange.com/users/877/rolandomysqldba)

* Вам все равно придется подключаться как клиент mysql:

Подключение и аутентификация

 --host <hostname> Подключиться к удаленному хосту для выполнения тестов (по умолчанию: localhost)
 --socket <socket> Использовать другой сокет для локального подключения
 --port <port>     Порт для подключения (по умолчанию: 3306)
 --user <username> Имя пользователя для аутентификации
 --pass <password> Пароль для аутентификации
 --defaults-file <path> файл по умолчанию для учетных данных

Поскольку вы используете удаленный хост, используйте параметры для предоставления значений из ОС

 --forcemem <size>  Объем установленной оперативной памяти в мегабайтах
 --forceswap <size> Объем настроенной памяти подкачки в мегабайтах

* Возможно, вам придется связаться с вашим удаленным системным администратором, чтобы спросить, сколько у вас ОЗУ и подкачки

Если в базе данных слишком много таблиц или очень большие таблицы, используйте это:

 --skipsize           Не перечислять таблицы и их типы/размеры (по умолчанию: вкл.)
                      (Рекомендуется для серверов с большим количеством таблиц)

**Вопрос: могу ли я установить этот проект с помощью homebrew на Apple Macintosh?**

Да! `brew install mysqltuner` можно использовать для установки этого приложения с помощью [homebrew](https://brew.sh/) на Apple Macintosh.

MySQLTuner и Vagrant
--

**MySQLTuner** содержит следующие конфигурации Vagrant:

* Fedora Core 30 / Docker

**Файл Vagrant** хранится в подкаталоге Vagrant.

* Выполните следующие действия после установки Vagrant:
    $ vagrant up

**MySQLTuner** содержит конфигурации Vagrant для целей тестирования и разработки

* Установите VirtualBox и Vagrant
  * <https://www.virtualbox.org/wiki/Downloads>
  * <https://www.vagrantup.com/downloads.html>
* Клонируйте репозиторий
  * git clone <https://github.com/jmrenouard/MySQLTuner-perl/.git>
* Установите плагины Vagrant vagrant-hostmanager и vagrant-vbguest
  * vagrant plugin install vagrant-hostmanager
  * vagrant plugin install vagrant-vbguest
* Добавьте образ Fedora Core 30 с официального сайта загрузки Fedora
  * vagrant box add --name generic/fedora30
* Создайте каталог данных
  * mkdir data

## настроить тестовые среды

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

Приветствуются вклады
--

Как внести свой вклад с помощью запроса на включение? Следуйте этому руководству: [Создание запроса на включение](https://opensource.com/article/19/7/create-pull-request-github)

Простые шаги для создания запроса на включение
--

* Сделайте форк этого проекта Github
* Клонируйте его в свою локальную систему
* Создайте новую ветку
* Внесите свои изменения
* Отправьте его обратно в свой репозиторий
* Нажмите кнопку Сравнить и запрос на включение
* Нажмите Создать запрос на включение, чтобы открыть новый запрос на включение
