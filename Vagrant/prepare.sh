#!/bin/sh
rm -f Vagrantfile
cp Vagrantfile_for_MariaDB10.0 Vagrantfile
mkdir data
vagrant plugin install vagrant-hostmanager
vagrant plugin install vagrant-vbguest
vagrant plugin install vagrant-proxyconf
vagrant --provision up
