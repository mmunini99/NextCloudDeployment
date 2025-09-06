#!/bin/bash
kubectl apply --server-side -f https://raw.githubusercontent.com/kubeflow/mpi-operator/master/deploy/v2beta1/mpi-operator.yaml
kubectl wait --for=condition=established --timeout=120s crd/mpijobs.kubeflow.org
# Check with kubectl get crd
if [ -z "$(kubectl get crd | grep mpijobs.kubeflow.org)" ]; then
    echo "MPI operator not deployed"
    exit 1
else
    echo "MPI operator deployed"
fi
