#!/bin/bash
MASTER_NAME="masternode"
MASTER_IP=192.168.133.80
export MASTER_IP


sudo su

sleep 30
scp -o StrictHostKeyChecking=no root@$MASTER_IP:/home/vagrant/admin.conf /home/vagrant/admin.conf

mkdir -p $HOME/.kube
cp -i /home/vagrant/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

scp -o StrictHostKeyChecking=no root@$MASTER_IP:/root/join.sh /root/join.sh

sed -i 's/kubeadm join/kubeadm join --cri-socket=unix:\/\/\/var\/run\/containerd\/containerd.sock/' /root/join.sh
bash /root/join.sh
