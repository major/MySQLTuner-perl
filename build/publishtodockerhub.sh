#!/bin/bash
# ==================================================================================
# Script: publishtodockerhub.sh
# Description: Tags and pushes the MySQLTuner Docker image to Docker Hub.
# Author: Jean-Marie Renouard
# Project: MySQLTuner-perl
# ==================================================================================


[ -f "./.env" ] && source ./.env
[ -f "../.env" ] && source ../.env

VERSION=$1

docker login -u $DOCKER_USER_LOGIN -p $DOCKER_USER_PASSWORD
docker tag jmrenouard/mysqltuner:latest jmrenouard/mysqltuner:$VERSION
docker push jmrenouard/mysqltuner:latest
docker push jmrenouard/mysqltuner:$VERSION