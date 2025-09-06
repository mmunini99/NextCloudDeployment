#!/bin/bash


sudo virsh net-destroy net-vm
sudo virsh net-undefine net-vm

echo "Network down"
