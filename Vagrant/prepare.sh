#!/bin/sh
rm -f Vagrantfile
cp Vagrantfile_for_MariaDB10.0 Vagrantfile
mkdir data
vagrant plugin install vagrant-hostmanager
vagrant plugin install vagrant-vbguest
vagrant box add --name fc23 https://download.fedoraproject.org/pub/fedora/linux/releases/23/Cloud/x86_64/Images/Fedora-Cloud-Base-Vagrant-23-20151030.x86_64.vagrant-virtualbox.box
vagrant up
