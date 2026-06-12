FROM ubuntu:latest@sha256:f3d28607ddd78734bb7f71f117f3c6706c666b8b76cbff7c9ff6e5718d46ff64

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

#Problem with generateion of CVE files
COPY ./vulnerabilities.csv /vulnerabilities.txt

ENTRYPOINT [ "perl", "/mysqltuner.pl", "--passwordfile", "/basic_passwords.txt",\
  "--nosysstat", "--defaults-file", "/defaults.cnf", "--cvefile", "/vulnerabilities.txt", \
  "--dumpdir", "/results", "--outputfile", \
  "/results/mysqltuner.txt", \
  "--reportfile", "/results/mysqltuner.html" , "--verbose" ]
