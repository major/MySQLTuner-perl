#!/bin/sh

(cd ..
echo "* GENERATING USAGE FILE"
pod2markdown mysqltuner.pl >USAGE.md
echo "* TIDYFY SCRIPT"
perltidy -b mysqltuner.pl
)
echo "* Udate CVE list"
perl updateCVElist.pl

git add ../vulnerabilities.csv ../mysqltuner.pl ./USAGE.md
git commit -m 'Update Vulnerabilities list
Identing mysqltuner
Update Usage information'