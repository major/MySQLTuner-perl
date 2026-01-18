#!/bin/sh
# ==================================================================================
# Script: clearContainer.sh
# Description: Kills and removes all running Docker containers.
# Author: Jean-Marie Renouard
# Project: MySQLTuner-perl
# ==================================================================================


docker ps | awk '{ print $NF}' |grep -v NAMES | xargs -n 1 docker kill
docker ps -a | awk '{ print $NF}' |grep -v NAMES | xargs -n 1 docker rm                                                                                                                   
docker ps -a     
