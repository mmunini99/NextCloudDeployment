#!/bin/bash
# Title

cd /home/vagrant
mkdir -p .kube
sudo cp /home/vagrant/admin.conf .kube/config
sudo chown $(id -u vagrant):$(id -g vagrant) .kube/config
