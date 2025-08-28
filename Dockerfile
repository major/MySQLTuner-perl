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
    libtext-template-perl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /results
RUN apt clean all
WORKDIR /
COPY ./mysqltuner.pl /mysqltuner.pl 
COPY ./vulnerabilities.csv /vulnerabilities.txt
COPY ./basic_passwords.txt /basic_passwords.txt
COPY ./template_example.tpl /template.tpl

ENTRYPOINT [ "perl", "/mysqltuner.pl", "--passwordfile", "/basic_passwords.txt",\
             "--cvefile", "/vulnerabilities.txt", "--nosysstat", "--defaults-file", \
             "/defaults.cnf", "--dumpdir", "/results", "--outputfile", \
             "/results/mysqltuner.txt", "--template", "/template.tpl", \
             "--reportfile", "/results/mysqltuner.html" ]
CMD ["--verbose" ]
