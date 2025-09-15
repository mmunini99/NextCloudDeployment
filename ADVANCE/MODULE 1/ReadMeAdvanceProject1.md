## Requirement


To run the code in **deploy_nextcloud** directory and so, make the deployment of the cloud system on your local PC or host machine through Kubernets cluster, the user needs on his/her local machine the following:

* Minikube
* Helm
* Kubectl

If your are using Windows, for me it is useful Ubuntu 24.04 WLS and DockerDesktop also.

## Customization

It could be that, conditional on host machine that will be used or personal goal, the user needs to make some personal modification to meet specific requirements. The **deploy_nextcloud** directory is organized in the following:

* secrets 
* pv-pvc
* nginx-ingress
* namespace
* manifest-metallb
* helm
* deployments

*Note* :  this code have been defined and tested on a host machine that has Windows as OS (WSL downloaded) and so, every command or oprations run has been executed on Ubuntu 24.04 WSL. Some operations done here, maybe not necessary for other OS.

## Steps for the deployment
At the beginning, the user needs to clone this GitHub repository. Then, open the terminal and move to the directory where it has saved the repository. Then, 

```bash
cd deploy_nextcloud
```

Firstly, start one single node in Kubernets using *minikube*, with docker driver. There are other drivers, but I did not try with them, so please keep docker driver in this project. So, the user need to run the following command (before activate Docker Desktop):
```bash
minikube start --driver=docker
```
It takes a minute and a half in my machine. The output should be similar to the following:
```bash
😄  minikube v1.36.0 on Ubuntu 24.04 (kvm/amd64)
✨  Using the docker driver based on user configuration
📌  Using Docker driver with root privileges
❗  For an improved experience it's recommended to use Docker Engine instead of Docker Desktop.
Docker Engine installation instructions: https://docs.docker.com/engine/install/#server
👍  Starting "minikube" primary control-plane node in "minikube" cluster
🚜  Pulling base image v0.0.47 ...
🔥  Creating docker container (CPUs=2, Memory=2900MB) ...
🐳  Preparing Kubernetes v1.33.1 on Docker 28.1.1 ...
    ▪ Generating certificates and keys ...
    ▪ Booting up control plane ...
    ▪ Configuring RBAC rules ...
🔗  Configuring bridge CNI (Container Networking Interface) ...
🔎  Verifying Kubernetes components...
    ▪ Using image gcr.io/k8s-minikube/storage-provisioner:v5
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

Use minikube with the virualization driver set to Docker. So, the Kubernetes node (only 1 since minikube) will run as Docker containers instead of VMs.

At this point, the user needs to run these two commands:
```bash
minikube addons enable metallb
minikube addons enable ingress
```

These enable MetalLB (for LoadBalancer --> service get externalIPs) and the NGINX Ingress controller inside Minikube (manages external access to services inside the cluster). It is very important. In my machine it takes 2 minutes to complete the operations.

Once done, it is needed that MetalLB manifest is fetched from GitHub repository and creates the resources needed. So, in the kubernets node MetalLB will be installed and will run. To do that, the user needs to rune the following command

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
```
and then wait for 3/4 minutes. Then run

```bash
kubectl apply -f manifest-metallb/metallb-config.yaml
```
so, using a manifest prepared it has been given MetalLB a range of IPs to hand out, and enabled it to advertise them. Now, any Service of type LoadBalancer in the cluster can get an external IP from that pool. *Note* : if this command gievs an error wait a bit longer and re-try. 

The expected output should be similar to:
```bash
ipaddresspool.metallb.io/first-pool created
l2advertisement.metallb.io/l2adv created
```

**Note** : Here, I will show how to install ingress becuase if you don't have Windows with WSL it should work, however due to problem with WLS at the end to expose the service I need to port forwarding.
Then, run the following command:
```bash
# (Optional) clean up old conflicting resources
kubectl delete ingressclass nginx || true

# Install NGINX Ingress Controller from NGINX Inc.
helm pull oci://ghcr.io/nginxinc/charts/nginx-ingress --untar --version 0.17.1
kubectl apply -f nginx-ingress/crds/
helm install nginx-ingress oci://ghcr.io/nginxinc/charts/nginx-ingress --version 0.17.1
```


Wait 40 seconds for the container to be ready and running. To check run:

```bash
kubectl get pods -n default -l app.kubernetes.io/name=nginx-ingress
```

and the output should be similar to:

```bash
NAME                                       READY   STATUS    RESTARTS   AGE
nginx-ingress-controller-b8c6586f6-255c4   1/1     Running   0          38s
```

Then run the following script:
```bash
kubectl create namespace cloud


kubectl apply -f pv-pvc/nextcloud-pv.yaml
kubectl apply -f pv-pvc/nextcloud-pvc.yaml -n cloud
kubectl apply -f pv-pvc/mariadb-pv.yaml
kubectl apply -f pv-pvc/mariadb-pvc.yaml -n cloud

#PersistentVolume (PV) is a cluster-wide resource --> not tied to any namespace. 

#PersistentVolumeClaim (PVC) is a namespaced resource --> It lives inside a namespace.



kubectl apply -f secrets/sys-cloud-secrets.yaml -n cloud
kubectl apply -f secrets/mariadb-secrets.yaml -n cloud
kubectl apply -f secrets/redis-secrets.yaml -n cloud

kubectl apply -f deployments/mariadb-deployment.yaml -n cloud
kubectl apply -f deployments/mariadb-service.yaml -n cloud


kubectl apply -f deployments/redis-deployment.yaml -n cloud
kubectl apply -f deployments/redis-service.yaml -n cloud

Step9:
helm repo add nextcloud https://nextcloud.github.io/helm/     #could be skipped if already present
helm repo update

helm install nextcloud nextcloud/nextcloud -f helm/values.yaml -n cloud

kubectl apply -f helm/ingress_init.yaml -n cloud
```

Then ssh into the node and do the following:
```bash
minikube ssh
sudo mkdir -p /mnt/data/nextcloud
#Since this pod (the one of the project) is running with fsGroup: 33 (which corresponds to www-data group), run:

sudo chown -R 33:33 /mnt/data/nextcloud

exit
```

Then, the last thing is to modify a config file, so run:
```bash
kubectl edit configmap -n kube-system kube-proxy
```

and vim tool will appear. The user need to do the following changes:
```bash
ipvs:
  strictARP: false  --> to --> true

mode: "" --> to -- > "ipvs"
```

*Note* : if the user does not vim, press *i* and do the changes, then press *esc* and type *:wq* and press *Enter*.

Make the restart:
```bash
kubectl -n kube-system delete pods -l k8s-app=kube-proxy
```

Then, wait for the service to run (5 minutes):

```bash
kubectl get pods -n cloud
```

and the output should be similar to:
```bash
NAME                         READY   STATUS    RESTARTS   AGE
mariadb-74b559bd8f-ks6zh     1/1     Running   0          6m26s
nextcloud-5ddd555b49-snrxd   1/1     Running   0          6m23s
nextcloud-redis-master-0     1/1     Running   0          6m23s
redis-6df979df64-5fpm6       1/1     Running   0          6m26s
```

Then, since problems with WLS, to reach from web browser the service:

```bash
kubectl port-forward svc/nextcloud 8080:80 -n cloud
```

and open a web browser, like Chrome, DuckDuckGo, Mozilla FireFox ... and navigate at http://localhost:8080. (to enter as admin, username is admin and password is admin123).

Another solution, relies on opening a separate terminal window and from there run:
```bash
minikube tunnel
```

then on the terminal where all the deploy has been completed, run this comand:
```bash
kubectl get services -n cloud
```

then taking the IP on *EXTERNAL-IP* at *NAME nextcloud* the use can navigate into NextCloud UI at *http://IP*. 

Outside WLS the user could have been access, thanks ingress, to nextcloud.local, meaning that by running (namespace cloud, since created before for organizing better resources):
```bash
kubectl get ingress -n cloud
```

the output would be like:
```bash
NAME                CLASS   HOSTS             ADDRESS          PORTS   AGE
nextcloud-ingress   nginx   nextcloud.local   192.168.49.240   80      10m
```
so, last thing to access with nextcloud.local would be to map the IP address to nextcloud.local in host file on the user host machine.

To close everything:
```bash
minikube delete
```
