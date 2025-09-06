#!/bin/bash
export POD_CIDR=10.17.0.0/16

kubectl create namespace flannel
kubectl label --overwrite ns flannel pod-security.kubernetes.io/enforce=privileged
helm repo add flannel https://flannel-io.github.io/flannel/
helm repo update
helm install flannel --set podCidr="$POD_CIDR" flannel/flannel -n flannel
