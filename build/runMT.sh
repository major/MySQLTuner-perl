#!/bin/sh

input="./build/configimg.conf"

while IFS='' read -r line
do
    [ -z "$line" ] && continue
    container_port=$(echo "$line" | cut -d\; -f1)
    container_name=$(echo "$line" | cut -d\; -f2)
    container_datadir=$(echo "$line" | cut -d\; -f3)
    image_name=$(echo "$line" | cut -d\; -f4)

    if [ -n "$1" -a "$1" != "$container_name" ]; then
        continue
    fi
    shift
    sudo rm -f /var/lib/mysql
    sudo ln -sf $container_datadir /var/lib/mysql
    sudo chmod 777 /var/lib/mysql

    #sudo docker logs $container_name > /tmp/mysqld.log
    ls -ls /var/lib | grep -E 'mysql$'
    #set +x
    perl mysqltuner.pl $* --host 127.0.0.1 --port $container_port
    exit $?
done < "$input"
