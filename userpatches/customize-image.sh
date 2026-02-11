#!/bin/bash

# This script is called by the Armbian build framework during image creation.
# It runs inside the chroot of the target image.
# Reference: https://docs.armbian.com/Developer-Guide_User-Configurations/

Main() {
    echo ">>> OneCloud Custom Image Script Starting..."

    # =========================================================================
    # Install Docker CE + Docker Compose
    # =========================================================================
    echo ">>> Installing Docker CE..."

    # Install prerequisites
    apt-get update
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Detect OS for correct Docker repo
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID}"
        OS_CODENAME="${VERSION_CODENAME}"
    else
        OS_ID="debian"
        OS_CODENAME="bookworm"
    fi

    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS_ID} ${OS_CODENAME} stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt-get update
    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # Enable Docker on boot
    systemctl enable docker
    systemctl enable containerd

    # Configure Docker daemon
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<'DOCKER_EOF'
{
    "storage-driver": "overlay2",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "default-address-pools": [
        {"base": "172.17.0.0/16", "size": 24}
    ]
}
DOCKER_EOF

    echo ">>> Docker CE installed successfully"

    # =========================================================================
    # Install useful tools
    # =========================================================================
    echo ">>> Installing additional tools..."
    apt-get install -y \
        htop \
        iotop \
        curl \
        wget \
        nano \
        net-tools \
        iperf3 \
        dnsutils \
        tree \
        tmux \
        git

    # =========================================================================
    # System optimizations for low-memory device (1GB RAM)
    # =========================================================================
    echo ">>> Applying system optimizations..."

    # Optimize sysctl for low-memory
    cat >> /etc/sysctl.d/99-onecloud.conf <<'SYSCTL_EOF'
# OneCloud optimizations for 1GB RAM
vm.swappiness=60
vm.vfs_cache_pressure=100
vm.dirty_ratio=10
vm.dirty_background_ratio=5
net.core.somaxconn=1024
net.ipv4.tcp_fastopen=3
SYSCTL_EOF

    # =========================================================================
    # Cleanup
    # =========================================================================
    echo ">>> Cleaning up..."
    apt-get clean
    rm -rf /var/lib/apt/lists/*

    echo ">>> OneCloud Custom Image Script Complete!"
}

Main "$@"
