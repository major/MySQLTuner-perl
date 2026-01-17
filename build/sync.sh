#!/bin/sh
# ==================================================================================
# Script: sync.sh
# Description: Synchronizes local repo with upstream major/MySQLTuner-perl.
# Author: Jean-Marie Renouard
# Project: MySQLTuner-perl
# ==================================================================================

# Used to sync the original project with local project.

#Save existing working
git stash

#add project url to current repository as upstream-live
git remote add upstream-live https://github.com/jmrenouard/MySQLTuner-perl/

#Fetch updated code
git fetch upstream-live

#Going back to the master branch for mearging latest code
git checkout master

#Merge latest code with master branch.
git merge upstream-live/master
