FROM ubuntu:latest

LABEL maintainer="jmrenouard@gmail.com"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt upgrade -y && apt-get install -yq --no-install-recommends \
    apt-utils \
    curl \
    wget \
    perl \
    perl-doc \
    mysql-client \
    libjson-perl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "Downloading MySQL Tuner script ..." \
    && wget --no-check-certificate https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl -O /mysqltuner.pl \
    && wget --no-check-certificate https://raw.githubusercontent.com/major/MySQLTuner-perl/master/basic_passwords.txt -O /basic_passwords.txt \
    && wget --no-check-certificate https://raw.githubusercontent.com/major/MySQLTuner-perl/master/vulnerabilities.csv -O /vulnerabilities.csv

ENTRYPOINT ["perl", "/mysqltuner.pl", "--passwordfile", "/basic_passwords.txt" , "--cvefile", "/vulnerabilities.txt", "--nosysstat", "--defaults-file", "/defaults.cnf" ]
CMD ["--verbose"]
