#!/bin/sh

VERSION=1.4.5

mkdir -p mysqltuner-$VERSION
cp ../mysqltuner.pl mysqltuner.spec ../LICENSE mysqltuner-$VERSION
tar czf mysqltuner-${VERSION}.tgz mysqltuner-$VERSION
rpmbuild -ta mysqltuner-${VERSION}.tgz 2>/dev/null| grep --color=never '\.rpm' | cut -d: -f2 > ./lrpm.txt
mv $(cat ./lrpm.txt) .
rm -rf mysqltuner-$VERSION ./lrpm.txt
