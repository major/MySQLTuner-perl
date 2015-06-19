#!/bin/sh

BUILD_DIR=`dirname $(readlink -f $0)`

VERSION=$(grep -i tunerversion $BUILD_DIR/../mysqltuner.pl | grep = | cut -d\" -f2)
cd $BUILD_DIR
perl -pe "s/%VERSION%/$VERSION/g" mysqltuner.spec.tpl > mysqltuner.spec
mkdir -p $BUILD_DIR/mysqltuner-$VERSION
cp $BUILD_DIR/../mysqltuner.pl mysqltuner.spec $BUILD_DIR/../LICENSE $BUILD_DIR/../basic_passwords.txt $BUILD_DIR/mysqltuner-$VERSION  
tar czf $BUILD_DIR/mysqltuner-${VERSION}.tgz mysqltuner-$VERSION
rpmbuild -ta mysqltuner-${VERSION}.tgz 2>/dev/null| grep --color=never '\.rpm' | cut -d: -f2 > ./lrpm.txt
mv $(cat ./lrpm.txt) .
rm -rf mysqltuner-$VERSION ./lrpm.txt
