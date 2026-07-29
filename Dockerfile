FROM ubuntu:latest@sha256:b7f48194d4d8b763a478a621cdc81c27be222ba2206ca3ca6bc42b49685f3d9e

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
COPY ./basic_passwords.txt /basic_passwords.txt
RUN touch /defaults.cnf

#Problem with generateion of CVE files
COPY ./vulnerabilities.csv /vulnerabilities.txt

ENTRYPOINT [ "perl", "/mysqltuner.pl", "--passwordfile", "/basic_passwords.txt",\
  "--nosysstat", "--defaults-file", "/defaults.cnf", "--cvefile", "/vulnerabilities.txt", \
  "--dumpdir", "/results", "--outputfile", \
  "/results/mysqltuner.txt", \
  "--reportfile", "/results/mysqltuner.html" ]
