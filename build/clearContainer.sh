#!/bin/sh

docker ps | awk '{ print $NF}' |grep -v NAMES | xargs -n 1 docker kill
docker ps -a | awk '{ print $NF}' |grep -v NAMES | xargs -n 1 docker rm                                                                                                                   
docker ps -a     
