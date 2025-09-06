#!/bin/bash
sudo su


cat << EOF | tee /etc/containers/registries.conf
[registries.search]
registries = ['docker.io']
EOF


systemctl start docker
systemctl enable docker


sleep 3
docker info > /dev/null 2>&1 || {
    echo "Docker not ready, waiting..."
    sleep 5
}

cd /home/vagrant/ompi_osu_docker


build_and_export() {
    local dockerfile=$1
    local image_name=$2
    local build_args=${3:-""}
    
    if [ -f "$dockerfile" ]; then
        echo "Building $image_name from $dockerfile..."
        if docker build $build_args -f "$dockerfile" -t "$image_name" .; then
            
            
            
            docker save "$image_name" -o "/tmp/${image_name}.tar"
            if ctr -n k8s.io images import "/tmp/${image_name}.tar"; then
                
                rm "/tmp/${image_name}.tar"
            else
                echo "Failed to export $image_name to containerd"
            fi
        else
            echo "Failed to build $image_name"
            return 1
        fi
    else
        echo "$dockerfile not found, skipping $image_name"
        return 1
    fi
}

# Build all required images
build_and_export "openmpi-builder.Dockerfile" "my-builder"
build_and_export "osu-code-provider.Dockerfile" "osu-code-provider" 
build_and_export "openmpi.Dockerfile" "my-operator"

# Build main benchmark image if Dockerfile exists
if [ -f "Dockerfile" ]; then
    build_and_export "Dockerfile" "my-osu-bench"
else
    echo "⚠ Main Dockerfile not found, skipping my-osu-bench"
fi


echo "Docker images built:"
docker images | grep -E "(my-builder|osu-code-provider|my-operator|my-osu-bench)"


echo "Images available to Kubernetes (containerd):"
crictl images | grep -E "(my-builder|osu-code-provider|my-operator|my-osu-bench)" || echo "No custom images found in containerd"

# Clean up Docker images to save space (optional)
# docker rmi my-builder my-operator osu-code-provider my-osu-bench 2>/dev/null || true

# Stop Docker to prevent conflicts with containerd as Kubernetes CRI
systemctl stop docker

# Fix ownership
chown -R vagrant:vagrant /home/vagrant/ompi_osu_docker

