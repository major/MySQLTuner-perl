#!/bin/sh
# ==================================================================================
# Script: updateStaff.sh
# Description: Updates project metadata, USAGE.md, FEATURES.md, and CVE lists.
# Author: Jean-Marie Renouard
# Project: MySQLTuner-perl
# ==================================================================================


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
bash ./genFeatures.sh

git add ../vulnerabilities.csv ../mysqltuner.pl ../USAGE.md ../FEATURES.md
git commit -m 'Update Vulnerabilities list
Indenting mysqltuner
Update Usage information
Regenerate fetures list'
