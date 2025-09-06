#!/bin/bash

# Broadcast Two Nodes Benchmark
echo "Starting Broadcast Two Nodes Benchmark..."

# Create k8s namespace 
kubectl create namespace osu

export OUTPUT=bcast-two-nodes-results.txt
echo "Broadcast Two Nodes Benchmark Results" > $OUTPUT
echo "=====================================" >> $OUTPUT
echo "Test started at: $(date)" >> $OUTPUT
echo "" >> $OUTPUT

# Apply the YAML configuration
cat <<EOF | kubectl apply -f - --namespace osu
apiVersion: kubeflow.org/v2beta1
kind: MPIJob
metadata:
  name: bcast-two-nodes
spec:
  slotsPerWorker: 1
  runPolicy:
    cleanPodPolicy: Running
  sshAuthMountPath: /home/mpiuser/.ssh
  mpiImplementation: MPICH
  mpiReplicaSpecs:
    Launcher:
      replicas: 1
      template:
        spec:
          containers:
          - image: localhost/my-osu-bench:latest
            imagePullPolicy: Never
            name: osu-launcher
            securityContext:
              runAsUser: 1000
            args:
            - mpirun
            - -n
            - "2"
            - /usr/local/libexec/osu-micro-benchmarks/mpi/collective/osu_bcast
            - -f
            - -z
            - -i
            - "10000"
            - -m
            - "4194304"
    Worker:
      replicas: 2
      template:
        metadata:
          labels:
            app: osu-worker
        spec:
          containers:
          - image: localhost/my-osu-bench:latest
            imagePullPolicy: Never
            name: osu-worker
            securityContext: 
              runAsUser: 1000
            command:
            args:
            - /usr/sbin/sshd
            - -De
            - -f
            - /home/mpiuser/.sshd_config
            readinessProbe:
              tcpSocket:
                port: 2222
              initialDelaySeconds: 2
          topologySpreadConstraints:
          - maxSkew: 1
            topologyKey: kubernetes.io/hostname
            whenUnsatisfiable: DoNotSchedule
            labelSelector:
              matchLabels:
                app: osu-worker
EOF

echo "MPIJob applied successfully. Waiting for completion..."

# Wait for the job to complete
export STATUS=""
while [ "$STATUS" != "Completed" ]; do
    STATUS=$(kubectl get pod -n osu | grep launcher | awk '{print $3}')
    echo "Running Broadcast Two Nodes benchmark... | Status: $STATUS"
    sleep 5
done

# Get results
export POD_NAME=$(kubectl get pods -n osu | grep launcher | awk '{print $1}')
echo "Collecting results from pod: $POD_NAME"
kubectl logs $POD_NAME -n osu >> $OUTPUT

echo "" >> $OUTPUT
echo "Test completed at: $(date)" >> $OUTPUT
echo "Status: SUCCESS"

# Clean up the resources
kubectl delete mpijob bcast-two-nodes --namespace osu
kubectl delete namespace osu

echo "Broadcast Two Nodes benchmark completed successfully!"
echo "Results saved to: $OUTPUT"