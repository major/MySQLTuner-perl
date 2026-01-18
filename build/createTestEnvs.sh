#!/bin/sh
# ==================================================================================
# Script: createTestEnvs.sh
# Description: Initializes the Docker environment for database tests.
# Author: Jean-Marie Renouard
# Project: MySQLTuner-perl
# ==================================================================================


source build/bashrc

systemctl status docker &>/dev/null
if [ $? -ne 0 ];then
    sudo dnf install -y yum-utils device-mapper-persistent-data lvm2
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager \
    --add-repo \
    https://download.docker.com/linux/fedora/docker-ce.repo

    sudo dnf -y install docker-ce docker-ce-cli containerd.io
    dnf list docker-ce --showduplicates | sort -r

    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker vagrant
    sudo systemctl daemon-reload
fi

sh build/createMassDockerImages.sh

sh build/fetchSampleDatabases.sh clean
sh build/fetchSampleDatabases.sh fetchall

exec_mysqls build/configimg.conf mysql contents/sakila-db/sakila-schema.sql
exec_mysqls build/configimg.conf mysql contents/sakila-db/sakila-data.sql