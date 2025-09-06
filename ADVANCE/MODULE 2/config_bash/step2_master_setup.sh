#!/bin/bash

MASTER_NAME="masternode"

sudo su



systemctl status containerd --no-pager
echo "Containerd socket check:"
ls -la /var/run/containerd/containerd.sock
echo "Testing containerd connection:"
ctr version


sleep 10


# Specify containerd as the CRI socket to avoid conflicts
kubeadm init --pod-network-cidr=10.17.0.0/16 --service-cidr=10.96.0.0/12 --cri-socket=unix:///var/run/containerd/containerd.sock --v=5 > /root/kubeinit.log 2>&1


if [ $? -ne 0 ]; then
    echo "kubeadm init failed. Check the logs:"
    cat /root/kubeinit.log
    exit 1
fi




cat /root/kubeinit.log | grep -A 1 "kubeadm join" > /root/join.sh
chmod +777 /root/join.sh


mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config


cp /etc/kubernetes/admin.conf /home/vagrant/admin.conf
chmod 666 /home/vagrant/admin.conf


export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl wait --for=condition=ready node $MASTER_NAME --timeout=120s
kubectl taint nodes $MASTER_NAME node-role.kubernetes.io/control-plane-
