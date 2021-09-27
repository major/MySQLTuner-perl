#!/bin/sh

(cd ..
echo "* GENERATING USAGE FILE"
pod2markdown mysqltuner.pl >USAGE.md
echo "* TIDYFY SCRIPT"
perltidy -b mysqltuner.pl
)
echo "* Update CVE list"
perl updateCVElist.pl
dos2unix ../mysqltuner.pl
git add ../vulnerabilities.csv ../mysqltuner.pl ../USAGE.md
git commit -m 'Update Vulnerabilities list
Indenting mysqltuner
Update Usage information'
