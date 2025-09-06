## Requirement


To make the deployment of the two VMs on your local PC or host machine and make the tests with OSU Benchmarking inside a Kubernetes cluster made by one or two nodes, teh following tools are required:

* Libvirt
* Vagrant 
* This plug-in that the user can easily installed by : vagrant plugin install vagrant-libvirt

If your are using Windows, for me it is useful Ubuntu 24.04 WLS and the user should run it inside Linux home directory in the WSL filesystem, otherwise errors can arise.

In short, Libvirt is the engine that runs VMs, while Vagrant is the manager that tells the engine how to create/configure VMs automatically, through a VagrantFile that is present in the directory.

*Note* : If the user is using Windows it could be that running bash file arises problems, so do the following:
```bash
sudo apt update
sudo apt install dos2unix

dos2unix file name
```

# Define a network

The user should move to *deploy_net* directory to define the network needed for VMs. Run the following commands:
```bash
cd deploy_net # enter directory

bash start-network.sh # it will ask ubuntu wls password
```

The output should be similar to:
```bash
Network net-vm defined from net-config-structure.xml

Network net-vm started

Network net-vm marked as autostarted

Network status: OK
```

## Build and provision the VMs

Here, the user will create a VM that will be the master, *masternode*, and a second VM the *workernode*. To do that 
```bash
cd ..

vagrant up --no-parallel
```

The two VMs will have Ubuntu 22.04 as OS and the flag --no-parallel guarantees teh user that the master VM will be defined, set up and deploye before the worker VM. Two VMs will be created with *masternode* and *workernode* names. The user will need to wait (at least from experience in my local machine) around 20 minutes.

The, to check that everything worked, teh user can tries to connect into each VM:

* for master:

```bash
vagrant ssh masternode

sudo kubectl get nodes

exit
```

The output should be like:

```bash
NAME         STATUS   ROLES           AGE   VERSION
masternode   Ready    control-plane   23m   v1.28.15
workernode   Ready    <none>          12m   v1.28.15
```

* for worker

```bash
vagrant ssh workernode

exit
```


Now that the VMs have been defined and builted, ssh into the master VM adn run the following commands:

```bash
cd /home/vagrant/ompi_osu_docker

# Rebuild the base images first
sudo podman build -f openmpi-builder.Dockerfile -t localhost/my-builder:latest .
sudo podman build -f osu-code-provider.Dockerfile -t localhost/osu-code-provider:latest .
sudo podman build -f openmpi.Dockerfile -t localhost/my-operator:latest .
```

then create the Dockerfile:

```bash
cat > Dockerfile << 'EOF'
# Multi-stage build using your local images
FROM localhost/osu-code-provider:latest AS source
FROM localhost/my-builder:latest AS builder

# Copy source code from provider
COPY --from=source /code /code

# Build OSU benchmarks
WORKDIR /code/osu-micro-benchmarks-7.3
RUN ./configure CC=mpicc CXX=mpicxx --prefix=/usr/local \
    && make -j$(nproc) \
    && make install

# Final runtime image
FROM localhost/my-operator:latest

# Copy built benchmarks
COPY --from=builder /usr/local /usr/local

# Install SSH server
RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-server && \
    rm -rf /var/lib/apt/lists/*

# Setup SSH for mpiuser (who already exists in base image)
RUN mkdir -p /home/mpiuser/.ssh && \
    ssh-keygen -t rsa -f /home/mpiuser/.ssh/id_rsa -N '' && \
    cat /home/mpiuser/.ssh/id_rsa.pub >> /home/mpiuser/.ssh/authorized_keys && \
    chmod 600 /home/mpiuser/.ssh/authorized_keys && \
    chmod 600 /home/mpiuser/.ssh/id_rsa && \
    chown -R mpiuser:mpiuser /home/mpiuser/.ssh

# SSH daemon config
RUN echo "Port 2222" > /home/mpiuser/.sshd_config && \
    echo "Protocol 2" >> /home/mpiuser/.sshd_config && \
    echo "UsePrivilegeSeparation no" >> /home/mpiuser/.sshd_config && \
    echo "PidFile /home/mpiuser/.sshd.pid" >> /home/mpiuser/.sshd_config && \
    echo "HostKey /home/mpiuser/.ssh/id_rsa" >> /home/mpiuser/.sshd_config && \
    echo "AuthorizedKeysFile /home/mpiuser/.ssh/authorized_keys" >> /home/mpiuser/.sshd_config && \
    echo "ChallengeResponseAuthentication no" >> /home/mpiuser/.sshd_config && \
    echo "UsePAM no" >> /home/mpiuser/.sshd_config && \
    echo "PubkeyAuthentication yes" >> /home/mpiuser/.sshd_config && \
    chown mpiuser:mpiuser /home/mpiuser/.sshd_config

USER mpiuser
WORKDIR /home/mpiuser

CMD ["/usr/sbin/sshd", "-De", "-f", "/home/mpiuser/.sshd_config"]
EOF
```


and build it by running the following command:

```bash
sudo podman build -t localhost/my-osu-bench:latest .
```
At this point, it is necessary to copy the necessary file into the worker VM, by running the following commands. *Note* : when asked type yes and the password asked for ssh into workernode is *vagrant*.

```bash
sudo podman save localhost/my-osu-bench:latest -o /tmp/my-osu-bench.tar
sudo ctr -n k8s.io images import /tmp/my-osu-bench.tar

scp /tmp/my-osu-bench.tar vagrant@192.168.133.81:/tmp/
ssh vagrant@192.168.133.81 "sudo ctr -n k8s.io images import /tmp/my-osu-bench.tar"

sudo crictl images | grep my-osu-bench
ssh vagrant@192.168.133.81 "sudo crictl images | grep my-osu-bench"

rm /tmp/my-osu-bench.tar
ssh vagrant@192.168.133.81 "rm /tmp/my-osu-bench.tar"
```

Once completed thsi steps, to verify everything worker run:
```bash
sudo podman images -a
```

and the output should be like:

```bash
localhost/my-osu-bench       latest      aff8f3b1c9e3  3 minutes ago  253 MB
localhost/my-operator        latest      e98b3315b22f  6 minutes ago  215 MB
localhost/osu-code-provider  latest      e6934e9f170a  7 minutes ago  144 MB
localhost/my-builder         latest      25c97fadbf28  7 minutes ago  537 MB
docker.io/library/debian     bullseye    a441a73edf10  2 weeks ago    130 MB
docker.io/mpioperator/base   latest      376719f48815  10 months ago  145 MB
```

Finally, the user needs to install the operator MPI can by applying the manifests to the Kubernetes nodes. Run the following being in master node VM:

```bash
cd ..

bash mpi_setup.sh
```

and output should be like:
```bash
namespace/mpi-operator serverside-applied
customresourcedefinition.apiextensions.k8s.io/mpijobs.kubeflow.org serverside-applied
serviceaccount/mpi-operator serverside-applied
clusterrole.rbac.authorization.k8s.io/kubeflow-mpijobs-admin serverside-applied
clusterrole.rbac.authorization.k8s.io/kubeflow-mpijobs-edit serverside-applied
clusterrole.rbac.authorization.k8s.io/kubeflow-mpijobs-view serverside-applied
clusterrole.rbac.authorization.k8s.io/mpi-operator serverside-applied
clusterrolebinding.rbac.authorization.k8s.io/mpi-operator serverside-applied
deployment.apps/mpi-operator serverside-applied
customresourcedefinition.apiextensions.k8s.io/mpijobs.kubeflow.org condition met
MPI operator deployed
```


and then the user need to deploy the flannel network to the Kubernetes cluster (agtain from master node VM)

```bash
 bash flannel_setup.sh
```

and output should be like:

```bash
namespace/flannel created
namespace/flannel labeled
"flannel" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "flannel" chart repository
Update Complete. ⎈Happy Helming!⎈
NAME: flannel
LAST DEPLOYED: Sat Aug 30 11:56:50 2025
NAMESPACE: flannel
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

## Run the test

There have been provided three different kind of test:

* **latency** between two pods on same node and whene there is a pod in *masternode* and *workernode*.
Two collective operations:

* **broadcast** between two pods on same node and whene there is a pod in *masternode* and *workernode*.
* **all reduce** between two pods on same node and whene there is a pod in *masternode* and *workernode*.


To run a test, the user need to move into *define_benchmark* folder and rune the following command:
```bash
cd define_benchmark

bash filname
```

where filename is selected from : 

* allreduce-one-node.sh , allreduce-two-nodes.sh
* bcast-one-node.sh , bcast-two-nodes.sh
* p2p-one-node.sh , p2p-two-nodes.sh

To copy the results from the VM masternode to your local machine, run the following command from the directory in your local machine where you ant to save your results:

```bash
scp vagrant@192.168.133.80:/home/vagrant/define_benchmark/result_filename.txt .
```


To close and destroy the two VMs run teh following code:
```bash
vagrant destroy -f
```

and to down the network:
```bash
cd deploy_net/

bash stop-network.sh
```