#!/bin/sh
# Used to sync the original project with local project.

#Save existing working
git stash

#add project url to current repository as upstream-live
git remote add upstream-live https://github.com/major/MySQLTuner-perl

#Fetch updated code
git fetch upstream-live

#Going back to the master branch for mearging latest code
git checkout master

#Merge latest code with master branch.
git merge upstream-live/master
