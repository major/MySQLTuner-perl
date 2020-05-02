#!/bin/sh


DB_WORLD_URL="https://downloads.mysql.com/docs/world.sql.zip"
DB_WORLDX_URL="https://downloads.mysql.com/docs/world_x-db.zip"
DB_SAKILA_URL="https://downloads.mysql.com/docs/sakila-db.zip"
DB_MESSAGERIE_URL="https://downloads.mysql.com/docs/menagerie-db.zip"
DB_TESTDB_URL="https://github.com/datacharmer/test_db/archive/master.zip"

getVal()
{
    local vari=$1
    eval "echo \$$vari"
}
case "$1" in
    "fetchall")
        for sample in WORLD WORLDX SAKILA MESSAGERIE TESTDB; do
            sh $0 fetch $sample
        done
        ;;
    "fetch")
        [ -z "$2" ] && exit 1
        mkdir -p ./contents
        [ -f "contents/$(basename $(getVal "DB_$2_URL"))" ] || wget -O contents/$(basename $(getVal "DB_$2_URL")) $(getVal "DB_$2_URL")
        if [ $? -eq 0 ];then
             (cd contents; unzip $( basename $(getVal "DB_$2_URL")) )
        fi
        ;;
    "clean")
        rm -rf contents
        ;;
   *)
        echo "Unknown operation: $1"
        ;;
esac