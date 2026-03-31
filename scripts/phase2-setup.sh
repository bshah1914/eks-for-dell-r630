#!/bin/bash
set -euo pipefail

# Phase 2: Configure all VMs via SSH
# Run from Windows Git Bash

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -i ~/.ssh/id_rsa"
SSH_USER="ubuntu"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[SETUP]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

run_on() {
    local ip=$1
    shift
    ssh $SSH_OPTS ${SSH_USER}@${ip} "$@"
}

# === COMMON SETUP (all VMs) ===
setup_common() {
    local ip=$1
    local hostname=$2
    log "=== Common setup: $hostname ($ip) ==="

    run_on $ip "sudo bash -s" << 'COMMON_SCRIPT'
export DEBIAN_FRONTEND=noninteractive

# Update system
apt-get update -qq
apt-get upgrade -y -qq

# Install common packages
apt-get install -y -qq \
    curl wget vim htop net-tools gnupg ca-certificates \
    apt-transport-https software-properties-common \
    nfs-common open-iscsi jq unzip chrony

# Disable swap
swapoff -a
sed -i '/\sswap\s/d' /etc/fstab

# Kernel modules
modprobe overlay
modprobe br_netfilter
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

# Sysctl
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system > /dev/null 2>&1

echo "Common setup done!"
COMMON_SCRIPT
    log "$hostname common setup complete!"
}

# === DOCKER SETUP ===
setup_docker() {
    local ip=$1
    local hostname=$2
    log "=== Docker setup: $hostname ($ip) ==="

    run_on $ip "sudo bash -s" << 'DOCKER_SCRIPT'
export DEBIAN_FRONTEND=noninteractive

# Add Docker repo
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
usermod -aG docker ubuntu

# Configure Docker
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF

systemctl enable docker
systemctl restart docker
echo "Docker setup done!"
DOCKER_SCRIPT
    log "$hostname Docker installed!"
}

# === K8S MASTER SETUP ===
setup_k8s_master() {
    local ip=$1
    log "=== K8s Master setup ($ip) ==="

    run_on $ip "sudo bash -s" << 'K8S_SCRIPT'
export DEBIAN_FRONTEND=noninteractive

# Install containerd
apt-get install -y -qq containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Add K8s repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Initialize cluster
kubeadm init \
    --apiserver-advertise-address=192.168.50.10 \
    --pod-network-cidr=10.244.0.0/16 \
    --service-cidr=10.96.0.0/12

# Setup kubectl for ubuntu user
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

echo "K8s master initialized!"
K8S_SCRIPT

    # Install Flannel CNI
    run_on $ip "kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"

    # Get join command
    JOIN_CMD=$(run_on $ip "sudo kubeadm token create --print-join-command")
    echo "$JOIN_CMD" > /tmp/k8s_join_command.sh
    log "K8s Master ready! Join command saved."
}

# === K8S WORKER SETUP ===
setup_k8s_worker() {
    local ip=$1
    local hostname=$2
    log "=== K8s Worker setup: $hostname ($ip) ==="

    run_on $ip "sudo bash -s" << 'WORKER_SCRIPT'
export DEBIAN_FRONTEND=noninteractive

# Install containerd
apt-get install -y -qq containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Add K8s repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
echo "K8s packages installed!"
WORKER_SCRIPT

    # Join cluster
    if [ -f /tmp/k8s_join_command.sh ]; then
        JOIN_CMD=$(cat /tmp/k8s_join_command.sh)
        run_on $ip "sudo $JOIN_CMD"
        log "$hostname joined the cluster!"
    else
        err "Join command not found! Run master setup first."
    fi
}

# === MAIN ===
case "${1:-all}" in
    common)
        log "Running common setup on all VMs..."
        for entry in "192.168.50.10 k8s-master" "192.168.50.11 k8s-worker-1" "192.168.50.12 k8s-worker-2" \
                     "192.168.50.20 ollama-ai" "192.168.50.30 database" "192.168.50.40 devops" \
                     "192.168.50.50 monitoring" "192.168.50.60 productivity"; do
            setup_common $entry
        done
        ;;
    docker)
        log "Installing Docker on service VMs..."
        for entry in "192.168.50.20 ollama-ai" "192.168.50.30 database" "192.168.50.40 devops" \
                     "192.168.50.50 monitoring" "192.168.50.60 productivity"; do
            setup_docker $entry
        done
        ;;
    k8s)
        log "Setting up Kubernetes cluster..."
        setup_k8s_master 192.168.50.10
        setup_k8s_worker 192.168.50.11 k8s-worker-1
        setup_k8s_worker 192.168.50.12 k8s-worker-2
        ;;
    all)
        log "=== PHASE 2: Full Setup ==="
        log "Step 1/3: Common setup..."
        for entry in "192.168.50.10 k8s-master" "192.168.50.11 k8s-worker-1" "192.168.50.12 k8s-worker-2" \
                     "192.168.50.20 ollama-ai" "192.168.50.30 database" "192.168.50.40 devops" \
                     "192.168.50.50 monitoring" "192.168.50.60 productivity"; do
            setup_common $entry
        done

        log "Step 2/3: Docker on service VMs..."
        for entry in "192.168.50.20 ollama-ai" "192.168.50.30 database" "192.168.50.40 devops" \
                     "192.168.50.50 monitoring" "192.168.50.60 productivity"; do
            setup_docker $entry
        done

        log "Step 3/3: Kubernetes cluster..."
        setup_k8s_master 192.168.50.10
        setup_k8s_worker 192.168.50.11 k8s-worker-1
        setup_k8s_worker 192.168.50.12 k8s-worker-2

        log "=== PHASE 2 COMPLETE ==="
        ;;
    *)
        echo "Usage: $0 {common|docker|k8s|all}"
        ;;
esac
