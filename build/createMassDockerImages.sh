#!/bin/sh

input="./build/configimg.conf"
default_password="secret"

echo "[client]
user=root
password=$default_password" > $HOME/.my.cnf

chmod 600 $HOME/.my.cnf

[ -f "$input" ] || echo "
3306;mysql80;/var/lib/mysql8;mysql:8.0
3307;mysql57;/var/lib/mysql57;mysql:5.7
3308;mysql56;/var/lib/mysql56;mysql:5.6
3309;mysql55;/var/lib/mysql55;mysql:5.5

4306;percona80;/var/lib/percona8;percona/percona-server:8.0
4307;percona57;/var/lib/percona57;percona/percona-server:5.7
4308;percona56;/var/lib/percona56;percona/percona-server:5.6

5306;mariadb104;/var/lib/mariadb104;mariadb:10.4
5307;mariadb103;/var/lib/mariadb103;mariadb:10.3
5308;mariadb102;/var/lib/mariadb102;mariadb:10.2
5309;mariadb101;/var/lib/mariadb101;mariadb:10.1
5310;mariadb100;/var/lib/mariadb100;mariadb:10.0
5311;mariadb55;/var/lib/mariadb55;mariadb:5.5
" > "$input"

#

#echo '* PRUNING DOCKER SYSTEM DATA'

#[ "$1" = "clean" ] || docker system prune -a -f
# download all images
while IFS='' read -r line
do
    [ -z "$line" ] && continue
    container_port=$(echo "$line" | cut -d\; -f1)
    container_name=$(echo "$line" | cut -d\; -f2)
    container_datadir=$(echo "$line" | cut -d\; -f3)
    image_name=$(echo "$line" | cut -d\; -f4)

    if [ -n "$1" -a "$1" != "clean" ]; then
        echo $line | grep -q "$1"
        [ $? -eq 0 ] || continue
    fi
    echo "* PULLING DOCKER IMAGE: $image_name"
    docker images | grep -E " $image_name$"
    [ $? -ne 0 ] && docker pull $image_name

    echo "* REMOVING CONTAINER : $image_name"
    docker ps -a | grep -qE "$container_name^"
    docker rm -f $container_name

    if [ 1 -eq 0 ]; then
    echo "* DELETING DATADIR: $container_datadir"
    sudo rm -rf $container_datadir
    [ "$1" = "clean" ] && continue

    echo "* CREATING DATADIR: $container_datadir"
    sudo mkdir -p $container_datadir
    fi
    #sudo chown -R mysql.mysql $container_datadir
    sudo chmod 777 $container_datadir
    echo "* STARTING CONTAINER: $container_name($container_port/TCP) BASED ON $image_name -> $container_datadir"
    set -x
    docker run -d -e MYSQL_ROOT_PASSWORD=$default_password -p $container_port:3306 --name $container_name -v $container_datadir:/var/lib/mysql $image_name
    set +x
    sleep 6s
    echo "* LOGS: $container_name"
    docker logs $container_name
    echo "* LISTING PORTS: $container_name BASED ON $image_name"
    docker port $container_name

    echo "* LISTING VOLUMES: $container_name BASED ON $image_name"
    docker inspect -f "{{ .Mounts }}" $container_name

    echo "* LISTING $container_datadir"
    ls -ls $container_datadir
    #break
    docker logs $container_name | grep -q "ready for connections"
done < "$input"

echo "* LISTING DOCKER IMAGES"
docker images

echo "* LISTING DOCKER CONTAINER"
docker ps

