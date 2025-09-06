#!/bin/bash


sudo virsh net-define net-config-structure.xml 
sudo virsh net-start net-vm 
sudo virsh net-autostart net-vm 

echo "Network status: OK"

