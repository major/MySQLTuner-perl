#!/bin/sh
VERSION=${1:-"10.4"}
rm -f Vagrantfile
cp Vagrantfile_for_MariaDB${VERSION} Vagrantfile
mkdir data
vagrant plugin install vagrant-hostmanager
vagrant plugin install vagrant-vbguest
vagrant plugin install vagrant-proxyconf
vagrant --provision up
