FROM ubuntu:24.04@sha256:2198e4c65076e9cb0b3d695219df667c0e3b0072da64ca3c2648aca17dcecaf5

LABEL maintainer="jmrenouard@gmail.com"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -yq --no-install-recommends \
    apt-utils \
    curl \
    wget \
    perl \
    perl-doc \
    mysql-client \
    libjson-perl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && mkdir -p /results

WORKDIR /

COPY ./mysqltuner.pl /mysqltuner.pl
COPY ./vulnerabilities.csv /vulnerabilities.txt
COPY ./basic_passwords.txt /basic_passwords.txt
RUN touch /defaults.cnf

ENTRYPOINT [ "perl", "/mysqltuner.pl", "--passwordfile", "/basic_passwords.txt", \
             "--nosysstat", "--defaults-file", "/defaults.cnf", "--cvefile", "/vulnerabilities.txt", \
             "--dumpdir", "/results", "--outputfile", \
             "/results/mysqltuner.txt", \
             "--reportfile", "/results/mysqltuner.html" ]
CMD ["--verbose"]
