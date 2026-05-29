![MySQLTuner-perl](mtlogo2.png)

[!["Купите нам кофе"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/jmrenouard)

[![Статус проекта](https://opensource.box.com/badges/active.svg)](https://opensource.box.com/badges)
[![Статус тестов](https://github.com/jmrenouard/MySQLTuner-perl/workflows/Test/badge.svg)](https://github.com/jmrenouard/MySQLTuner-perl/actions)
[![Среднее время решения проблемы](https://isitmaintained.com/badge/resolution/jmrenouard/MySQLTuner-perl.svg)](https://isitmaintained.com/project/jmrenouard/MySQLTuner-perl "Среднее время решения проблемы")
[![Процент открытых проблем](https://isitmaintained.com/badge/open/jmrenouard/MySQLTuner-perl.svg)](https://isitmaintained.com/project/jmrenouard/MySQLTuner-perl "Процент все еще открытых проблем")
[![Лицензия GPL](https://badges.frapsoft.com/os/gpl/gpl.png?v=103)](https://opensource.org/licenses/GPL-3.0/)

**MySQLTuner** — это скрипт, написанный на Perl, который позволяет быстро просмотреть установку MySQL и внести коррективы для повышения производительности и стабильности. Текущие переменные конфигурации и данные о состоянии извлекаются и представляются в кратком формате вместе с некоторыми основными предложениями по производительности.

**MySQLTuner** поддерживает около 900+ индикаторов, KPI и рекомендаций (включая средневзвешенный показатель здоровья, прогнозное планирование мощностей и аудит SSL/TLS) для MySQL/MariaDB/Percona Server в этой последней версии.

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

![Статистика GitHub jmrenouard](https://github-readme-stats.vercel.app/api?username=jmrenouard&show_icons=true&theme=radical)

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

Спасибо [endoflife.date](https://endoflife.date/)

* См. [Поддерживаемые версии MariaDB](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/mariadb_support.md).
* См. [Поддерживаемые версии MySQL](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/mysql_support.md).

***Поддержка Windows частична***

* Windows теперь поддерживается
* Успешно запущен MySQLtuner в WSL2 (подсистема Windows для Linux)
* [https://docs.microsoft.com/en-us/windows/wsl/](https://docs.microsoft.com/en-us/windows/wsl/)

***НЕПОДДЕРЖИВАЕМЫЕ СРЕДЫ - НУЖНА ПОМОЩЬ***

***Расширенная аналитика и экосистема***

* **KPI средневзвешенного показателя здоровья**: общая оценка состояния базы данных (0-100) на основе производительности (40очков), безопасности (30очков) и отказоустойчивости (30очков).
* **Советник по интеллектуальной миграции LTS**: выявление рисков при миграции на современные версии LTS (MySQL 8.4/9.0+, MariaDB 11.x), включая удалённые переменные и устаревшие методы аутентификации.
* **Прогнозное планирование мощностей**: анализ запаса памяти (пик vs доступная RAM+Swap), прогнозирование роста дискового пространства, обнаружение ёмкости AUTO_INCREMENT близкой к максимуму.
* **Автообнаружение облака**: нативная поддержка AWS RDS/Aurora, GCP Cloud SQL, Azure (Flexible/Managed) и DigitalOcean. Автоматическое обнаружение через `@@version_comment` и переменные, специфичные для провайдера.
* **Адаптивная настройка под инфраструктуру**: обнаружение типов хранилищ SSD/NVMe vs HDD и архитектур ARM64/Graviton vs x86_64. Корректировка рекомендаций для `innodb_flush_neighbors` и `innodb_io_capacity`.
* **Аудит безопасности SSL/TLS**: проверка шифрования сессии, аудит версий TLS (предупреждение о TLSv1.0/1.1), срок действия сертификатов, применение `require_secure_transport`, проверка SSL для удалённых пользователей.
* **Аудит плагинов аутентификации**: обнаружение небезопасных плагинов (`mysql_native_password`, `sha256_password`), диагностика совместимости MySQL 9.x, рекомендации MariaDB `ed25519`/`unix_socket`.
* **Моделирование схемы и конвенции именования**: полный анализ структуры таблиц (отсутствие PK, типы суррогатных ключей, соответствие UTF-8, таблицы не-InnoDB), аудит конвенций именования (snake_case/camelCase, обнаружение множественного числа, префиксы булевых столбцов/дат) и анализ внешних ключей (столбцы `_id` без ограничений, несоответствия типов, аудит CASCADE).
* **Моделирование MySQL 8.0+ / MariaDB**: индексируемость столбцов JSON (генерируемые виртуальные столбцы), невидимые индексы, ограничения CHECK.
* **Движок Auto-Fix с управляемым исправлением**: генерация SQL-инструкций `SET GLOBAL` и блоков конфигурации `[mysqld]` из рекомендаций по настройке переменных.
* **Анализ исторических тенденций**: поглощение JSON-вывода предыдущих запусков через `--compare-file` для отслеживания тенденций QPS и роста данных.
* **Интеграция Sysbench**: анализ вывода sysbench для метрик QPS, TPS и латентности (Средн./95-й/Макс) через `--sysbench-file`.
* **Интеграция логов Container и Systemd**: автоматическое обнаружение логов из Docker, Podman, Kubectl/Kubernetes и журнала Systemd.

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
* Неограниченный доступ на чтение к серверу MySQL (см. Привилегии ниже)

***ПРИВИЛЕГИИ***
--

Для запуска MySQLTuner со всеми функциями требуются следующие привилегии:

**MySQL 8.0+**:

```sql
GRANT SELECT, PROCESS, SHOW DATABASES, EXECUTE, REPLICATION REPLICA, REPLICATION CLIENT, SHOW VIEW ON *.* TO 'mysqltuner'@'localhost';
```

**MariaDB 10.5+**:

```sql
GRANT SELECT, PROCESS, SHOW DATABASES, EXECUTE, BINLOG MONITOR, SHOW VIEW, REPLICATION SOURCE ADMIN, REPLICA MONITOR ON *.* TO 'mysqltuner'@'localhost';
```

**Старые версии**:

```sql
GRANT SELECT, PROCESS, EXECUTE, REPLICATION CLIENT, SHOW DATABASES, SHOW VIEW ON *.* TO 'mysqltuner'@'localhost';
```

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

**MySQLTuner** анализирует следующие области:

* **Система и ОС**: RAM, swap, открытые порты, параметры ядра, нагрузка, точки монтирования, сетевые интерфейсы
* **Версия сервера**: обнаружение EOL, архитектура, рекомендации 64-битной версии
* **Логи ошибок**: локальные файлы, контейнеры Docker/Podman, поды Kubernetes, журнал Systemd
* **Облако и инфраструктура**: AWS RDS/Aurora, GCP, Azure, DigitalOcean; SSD/NVMe vs HDD; ARM64/x86_64
* **Движки хранения**: InnoDB (buffer pool, redo log, chunk size), MyISAM, Aria, Galera, TokuDB, RocksDB
* **Безопасность**: анонимные пользователи, слабые пароли, аудит SSL/TLS, плагины аутентификации, уязвимости CVE
* **Соединения**: проценты использования, прерванные соединения, кэш потоков
* **Производительность**: сортировка/объединения/временные таблицы, глобальные буферы, кэш запросов, медленные запросы, использование памяти
* **Репликация**: состояние Source/Replica, отставание, GTID, semi-sync, multi-source
* **Performance Schema**: топ пользователей/хостов/запросов, латентность IO, ожидание блокировок, неиспользуемые индексы, избыточные индексы
* **Моделирование схемы**: анализ первичных ключей, конвенции именования, внешние ключи, типы данных, соответствие UTF-8, индексируемость JSON
* **Прогнозирование**: запас памяти, прогноз роста диска, ёмкость AUTO_INCREMENT
* **Показатель здоровья**: взвешенный KPI (0-100), агрегирующий результаты производительности, безопасности и отказоустойчивости

Скачивание/установка
--

> **Примечание:** Пакеты дистрибутивов Linux (например, `apt install mysqltuner` в Ubuntu/Debian, `yum`/`dnf` в RHEL/CentOS/Fedora) зачастую содержат значительно устаревшую версию MySQLTuner. Официального репозитория APT/YUM/DNF, отслеживающего последнюю версию, не существует. Для получения актуальной версии используйте один из методов прямой загрузки ниже.

Выберите один из этих методов:

1) Прямая загрузка скрипта (самый простой и короткий метод):

```bash
wget https://mysqltuner.pl/ -O mysqltuner.pl
wget https://raw.githubusercontent.com/jmrenouard/MySQLTuner-perl/master/basic_passwords.txt -O basic_passwords.txt
wget https://raw.githubusercontent.com/jmrenouard/MySQLTuner-perl/master/vulnerabilities.csv -O vulnerabilities.csv
```

2) Вы можете загрузить весь репозиторий, используя `git clone` или `git clone --depth 1 -b master`, за которым следует URL-адрес клонирования выше.

```bash
git clone --depth 1 -b master https://github.com/jmrenouard/MySQLTuner-perl.git
```

3) На Apple macOS установите через [Homebrew](https://brew.sh/):

```bash
brew install mysqltuner
```

4) Если вы работаете в **изолированной среде (air-gapped)** без прямого доступа к Интернету, загрузите файлы на машину с доступом к Интернету (или через прокси-сервер), а затем скопируйте `mysqltuner.pl`, `basic_passwords.txt` и `vulnerabilities.csv` на целевой сервер.

5) Docker: Скачайте и запустите официальный Docker-контейнер (теги доступны на Docker Hub: [jmrenouard/mysqltuner tags](https://hub.docker.com/r/jmrenouard/mysqltuner/tags?name=latest)):

```bash
docker pull jmrenouard/mysqltuner:latest
docker run --rm -it jmrenouard/mysqltuner --host <database_host> --user <username> --pass <password>
```

### Расположение релизов

* Официальные примечания к релизам и история изменений задокументированы в каталоге [releases/](releases/) этого репозитория (например, [releases/v2.8.44.md](releases/v2.8.44.md)).
* Теги релизов Git и архивы с исходным кодом доступны на странице [GitHub Releases](https://github.com/jmrenouard/MySQLTuner-perl/releases).

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

**Использование:** Создание автономного HTML-отчета (встроенная функция, не требует внешних модулей или библиотек CPAN)

```bash
perl mysqltuner.pl --reportfile=mysqltuner.html
```

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

**Использование:** интеграция результатов производительности Sysbench

```bash
perl mysqltuner.pl --sysbench-file=/путь/к/вывод_sysbench.txt
```

**Использование:** анализ исторических тенденций (сравнение с предыдущим запуском)

```bash
perl mysqltuner.pl --json --outputfile=run1.json
# ... некоторое время спустя ...
perl mysqltuner.pl --compare-file=run1.json
```

**Использование:** экспорт Markdown-файла по схеме (документация схемы)

```bash
perl mysqltuner.pl --verbose --schemadir=./schemas
```

**Использование:** экспорт данных с ограничением строк и сжатием gzip

```bash
perl mysqltuner.pl --verbose --dumpdir=./result --dump-limit=10000 --compress-dump
```

**Использование:** режим контейнера (анализ базы данных в Docker)

```bash
perl mysqltuner.pl --verbose --container docker:имя_контейнера_mysql
```

**Использование:** анализ структуры таблиц и конвенций именования

```bash
perl mysqltuner.pl --structstat
```

**Использование:** фильтрация вывода (показывать только проблемы)

```bash
perl mysqltuner.pl --nogood --noinfo
```

**Использование:** вывод JSON (для автоматизации и конвейеров отчётности)

```bash
perl mysqltuner.pl --json --outputfile=report.json
perl mysqltuner.pl --prettyjson
```

**Использование:** режим невыделенного сервера (общий хостинг)

```bash
perl mysqltuner.pl --nondedicated
```

Для полного списка всех доступных опций выполните `perl mysqltuner.pl --help` или обратитесь к документации [USAGE.md](https://github.com/jmrenouard/MySQLTuner-perl/blob/master/USAGE.md).

Поддержка облака
--

MySQLTuner теперь имеет экспериментальную поддержку облачных сервисов MySQL.

* `--cloud`: включить облачный режим. Это общий флаг для любого облачного провайдера.
* `--azure`: включить специальную поддержку Azure.
* `--ssh-host <hostname>`: хост SSH для облачных подключений.
* `--ssh-user <username>`: пользователь SSH для облачных подключений.
* `--ssh-password <password>`: пароль SSH для облачных подключений.
* `--ssh-identity-file <path>`: путь к файлу идентификации SSH для облачных подключений.

HTML-отчет и взвешенный показатель здоровья
--

MySQLTuner динамически рассчитывает **средневзвешенный показатель здоровья (KPI)** (общая оценка состояния базы данных по шкале от 0 до 100) на основе трех категорий:

1. **Производительность (макс. 40 очков)**: Оценка эффективности чтения буферного пула, соотношения временных таблиц на диске, коэффициента кэширования потоков и загрузки соединений.
2. **Безопасность (макс. 30 очков)**: Оценка конфигурации учетных записей пользователей, надежности паролей (проверяется офлайн), шифрования сессий SSL/TLS и использования плагинов аутентификации.
3. **Отказоустойчивость (макс. 30 очков)**: Оценка состояния и отставания репликации, настроек логирования и результатов моделирования схемы.

**Создание HTML-отчета**

Вы можете сгенерировать автономный HTML-отчет напрямую с помощью команды:

```bash
perl mysqltuner.pl --reportfile=mysqltuner.html
```

Эта функция полностью реализована на чистом Perl и имеет **нулевую зависимость от внешних библиотек** (не требуются модули CPAN или пакеты Python). Созданный отчет представляет собой интерактивную панель управления в темных тонах, отображающую:
- Индикатор общей оценки здоровья (Weighted Health Score)
- Подробный обзор показателей KPI (Производительность, Безопасность, Отказоустойчивость)
- Категоризированные списки рекомендаций (Общие рекомендации, Изменение настроек, Моделирование структуры данных, Безопасность, Системные параметры)
- Сворачиваемый лог полной консольной трассировки



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

После того, как вы его создадите, убедитесь, что он принадлежит вашему пользователю, а режим файла — 0600. Это должно предотвратить подглядывание за вашими учетными данными для входа в базу данных в обычных условиях.

**Вопрос: Я получаю «ERROR 1524 (HY000): Plugin 'unix_socket' is not loaded» даже при unix_socket=OFF. Как это исправить?**

Это происходит потому, что клиент MariaDB по умолчанию пытается использовать плагин `unix_socket`, если не указаны имя пользователя или пароль.

* **Решение 1 (рекомендуется):** Используйте файл `~/.my.cnf`, как описано выше, для предоставления явных учетных данных.
* **Решение 2:** Передайте учетные данные напрямую: `perl mysqltuner.pl --user root --pass ваш_пароль`.

**Вопрос: Как безопасно снова включить аутентификацию `unix_socket`?**

Если вы решите использовать `unix_socket` (который позволяет пользователю ОС `root` входить в MariaDB `root` без пароля), выполните следующие действия:

1. Убедитесь, что плагин включен в `/etc/my.cnf`: `unix_socket=ON` (или удалите `OFF`).
2. В MariaDB установите плагин аутентификации для пользователя root:

   ```sql
   ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;
   ```

3. Убедитесь, что плагин `auth_socket` или `unix_socket` имеет статус `ACTIVE` в `SHOW PLUGINS`.

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

 --forcemem <size>  Объем установленной оперативной памяти (в мегабайтах или с единицами измерения, например, 15G, 1024M)
 --forceswap <size> Объем настроенной памяти подкачки (в мегабайтах или с единицами измерения)

* Возможно, вам придется связаться с вашим удаленным системным администратором, чтобы спросить, сколько у вас ОЗУ и подкачки

Если в базе данных слишком много таблиц или очень большие таблицы, используйте это:

 --skipsize           Не перечислять таблицы и их типы/размеры (по умолчанию: вкл.)
                      (Рекомендуется для серверов с большим количеством таблиц)

**Вопрос: могу ли я установить этот проект с помощью homebrew на Apple Macintosh?**

Да! `brew install mysqltuner` можно использовать для установки этого приложения с помощью [homebrew](https://brew.sh/) на Apple Macintosh.

**Вопрос: я установил MySQLTuner через менеджер пакетов моего дистрибутива Linux (apt/yum/dnf). Как получить последнюю версию?**

Дистрибутивы Linux, такие как Ubuntu, Debian, RHEL и CentOS, зачастую включают в свои официальные репозитории устаревшую версию MySQLTuner. Например, Ubuntu 22.04 поставляет версию 1.7.17, тогда как последний выпуск может быть значительно новее.

Официального **репозитория APT/YUM/DNF**, отслеживающего последнюю версию MySQLTuner, в настоящее время не существует. Для получения последней версии используйте один из следующих методов:

* **Прямая загрузка (рекомендуется):**

```bash
wget https://mysqltuner.pl/ -O mysqltuner.pl
wget https://raw.githubusercontent.com/jmrenouard/MySQLTuner-perl/master/basic_passwords.txt -O basic_passwords.txt
wget https://raw.githubusercontent.com/jmrenouard/MySQLTuner-perl/master/vulnerabilities.csv -O vulnerabilities.csv
chmod +x mysqltuner.pl
```

* **Git clone:**

```bash
git clone --depth 1 -b master https://github.com/jmrenouard/MySQLTuner-perl.git
cd MySQLTuner-perl
perl mysqltuner.pl
```

* **Изолированные среды (air-gapped):** Если у вашего сервера нет прямого доступа к Интернету, загрузите файлы на хост с доступом к Интернету (или через прокси-сервер), а затем передайте `mysqltuner.pl`, `basic_passwords.txt` и `vulnerabilities.csv` на целевой сервер с помощью `scp`, `rsync` или другого метода передачи файлов.

MySQLTuner и Vagrant (устаревшее)
--

> **Примечание:** Тестовая среда на базе Vagrant считается устаревшей. Для современного тестирования используйте набор тестов на базе Docker через `make test-it` или `build/test_envs.sh`.

**Файл Vagrant** хранится в подкаталоге Vagrant.

## Настройка тестовых сред Docker

MySQLTuner включает инфраструктуру тестирования на базе Docker для мульти-версионной валидации:

```bash
# Создать и запустить все тестовые контейнеры
sh build/createTestEnvs.sh

# Загрузить хелперы окружения
source build/bashrc

# Подключиться к конкретной базе данных
mysql_percona80 sakila
```

**Поддерживаемые цели тестирования** (см. [поддержка MariaDB](mariadb_support.md) и [поддержка MySQL](mysql_support.md) для текущей матрицы совместимости):

* MySQL 8.0, 8.4, 9.x
* MariaDB 10.6, 10.11, 11.4, 11.8
* Percona Server 8.0

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
