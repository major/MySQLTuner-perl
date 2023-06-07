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

# Update Feature list
(
    echo -e "Features list for option: --feature (dev only)\n---\n\n"
    grep -E '^sub ' ../mysqltuner.pl | perl -pe 's/sub //;s/\s*\{//g'| sort -n | perl -pe 's/^/* /g'
) > ../FEATURES.md

git add ../vulnerabilities.csv ../mysqltuner.pl ../USAGE.md ../FEATURES.md
#git commit -m 'Update Vulnerabilities list
#Indenting mysqltuner
#Update Usage information'
