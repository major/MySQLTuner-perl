#!/bin/bash
set -xv

_DIR=$(dirname `readlink -f $0`)


ssh $1 mkdir /images/mysqltuner
rsync -avz ${_DIR}/.. $1:/images/mysqltuner

if [ "$2" = "run" ];then
	ssh $1 "su - mysql -c 'cd /images/mysqltuner; source /opt/mysql/myqenv myserver1;perl mysqltuner.pl --verbose --color'"
fi
