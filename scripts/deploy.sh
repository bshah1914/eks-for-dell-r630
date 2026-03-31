#!/bin/bash
set -euo pipefail

# Dell R630 Homelab - Full Deployment Script
# Usage: ./deploy.sh [phase1|phase2|phase3|phase4|phase5|all]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[DEPLOY]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Phase 1: Provision VMs with Terraform
phase1() {
    log "=== Phase 1: Provisioning VMs on ESXi ==="
    cd "$PROJECT_DIR/terraform"

    if [ ! -f terraform.tfvars ]; then
        error "terraform.tfvars not found. Copy terraform.tfvars.example and fill in your values."
    fi

    terraform init
    terraform plan -out=tfplan
    log "Review the plan above. Apply? (y/n)"
    read -r confirm
    if [ "$confirm" = "y" ]; then
        terraform apply tfplan
        log "VMs provisioned successfully!"
    else
        warn "Skipping VM provisioning."
    fi
}

# Phase 2: Configure VMs with Ansible
phase2() {
    log "=== Phase 2: Configuring VMs with Ansible ==="
    cd "$PROJECT_DIR/ansible"

    log "Testing connectivity..."
    ansible all -i inventory/hosts.ini -m ping

    log "Running common setup..."
    ansible-playbook -i inventory/hosts.ini site.yml
    log "VMs configured successfully!"
}

# Phase 3: Deploy Database & Monitoring
phase3() {
    log "=== Phase 3: Deploying Database & Monitoring ==="

    log "Starting PostgreSQL & Redis..."
    ssh ubuntu@192.168.50.30 "cd /opt/docker-compose/database && docker compose up -d"

    log "Waiting for database to be ready..."
    sleep 15

    log "Starting Monitoring stack..."
    ssh ubuntu@192.168.50.50 "cd /opt/docker-compose/monitoring && docker compose up -d"

    log "Database & Monitoring deployed!"
}

# Phase 4: Deploy Services
phase4() {
    log "=== Phase 4: Deploying Services ==="

    log "Deploying GitLab..."
    ssh ubuntu@192.168.50.40 "cd /opt/docker-compose/gitlab && docker compose up -d"

    log "Deploying Nextcloud..."
    ssh ubuntu@192.168.50.60 "cd /opt/docker-compose/nextcloud && docker compose up -d"

    log "Deploying WikiJS & Productivity tools..."
    ssh ubuntu@192.168.50.60 "cd /opt/docker-compose/productivity && docker compose up -d"

    log "Deploying Ollama & Open WebUI..."
    ssh ubuntu@192.168.50.20 "cd /opt/docker-compose/ollama && docker compose up -d"

    log "Pulling default AI models..."
    ssh ubuntu@192.168.50.20 "docker exec ollama ollama pull llama3.1 && docker exec ollama ollama pull mistral && docker exec ollama ollama pull codellama"

    log "All services deployed!"
}

# Phase 5: Deploy Kubernetes workloads
phase5() {
    log "=== Phase 5: Deploying Kubernetes Workloads ==="
    cd "$PROJECT_DIR/kubernetes"

    export KUBECONFIG=~/.kube/config

    log "Creating namespaces..."
    kubectl apply -f manifests/namespace.yml

    log "Installing Ingress Controller..."
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        -f helm-values/ingress-nginx.yml

    log "Deploying Portainer..."
    kubectl apply -f manifests/portainer.yml

    log "Kubernetes workloads deployed!"
}

# Copy docker-compose files to VMs
copy_configs() {
    log "=== Copying Docker Compose configs to VMs ==="
    cd "$PROJECT_DIR"

    scp -r docker-compose/database ubuntu@192.168.1.30:/opt/docker-compose/
    scp -r docker-compose/monitoring ubuntu@192.168.50.50:/opt/docker-compose/
    scp -r docker-compose/gitlab ubuntu@192.168.50.40:/opt/docker-compose/
    scp -r docker-compose/nextcloud ubuntu@192.168.50.60:/opt/docker-compose/
    scp -r docker-compose/productivity ubuntu@192.168.50.60:/opt/docker-compose/
    scp -r docker-compose/ollama ubuntu@192.168.50.20:/opt/docker-compose/

    log "Configs copied!"
}

case "${1:-}" in
    phase1) phase1 ;;
    phase2) phase2 ;;
    phase3) phase3 ;;
    phase4) phase4 ;;
    phase5) phase5 ;;
    copy)   copy_configs ;;
    all)
        phase1
        phase2
        copy_configs
        phase3
        phase4
        phase5
        ;;
    *)
        echo "Usage: $0 {phase1|phase2|phase3|phase4|phase5|copy|all}"
        echo ""
        echo "  phase1 - Provision VMs with Terraform"
        echo "  phase2 - Configure VMs with Ansible"
        echo "  copy   - Copy Docker Compose configs to VMs"
        echo "  phase3 - Deploy Database & Monitoring"
        echo "  phase4 - Deploy Services (GitLab, Nextcloud, Ollama)"
        echo "  phase5 - Deploy Kubernetes workloads"
        echo "  all    - Run all phases"
        ;;
esac
