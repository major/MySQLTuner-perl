#!/bin/sh

BUILD_DIR="$(dirname $(readlink -f "$0"))"

VERSION=$(grep -Ei 'my \$tunerversion' $BUILD_DIR/../mysqltuner.pl | grep = | cut -d\" -f2)
cd $BUILD_DIR
sh ./clean.sh

perl -pe "s/%VERSION%/$VERSION/g" mysqltuner.spec.tpl > mysqltuner.spec
mkdir -p $BUILD_DIR/mysqltuner-$VERSION
cp $BUILD_DIR/../mysqltuner.pl mysqltuner.spec $BUILD_DIR/../LICENSE $BUILD_DIR/../basic_passwords.txt $BUILD_DIR/../*.csv $BUILD_DIR/mysqltuner-$VERSION
pod2man $BUILD_DIR/../mysqltuner.pl | gzip > $BUILD_DIR/mysqltuner-$VERSION/mysqltuner.1.gz

tar czf $BUILD_DIR/mysqltuner-${VERSION}.tgz mysqltuner-$VERSION
rpmbuild -ta mysqltuner-${VERSION}.tgz 2>&1 | tee -a ./build.log
set -x
grep --color=never -E '(Wrote|crit)\S*:' $BUILD_DIR/build.log | cut -d: -f2 | xargs -I{} mv {} .
#rm -rf mysqltuner-$VERSION ./build.log
