# Dell R630 Homelab Infrastructure

Self-hosted productivity platform running on Dell R630 (192GB RAM, 40 CPU, 2TB Storage) with ESXi.

## Architecture

```
ESXi Hypervisor (Dell R630)
├── K8s Master VM    (4 vCPU, 8GB RAM, 100GB)
├── K8s Worker 1 VM  (8 vCPU, 32GB RAM, 200GB)
├── K8s Worker 2 VM  (8 vCPU, 32GB RAM, 200GB)
├── AI/Ollama VM     (8 vCPU, 64GB RAM, 300GB)
├── Database VM      (4 vCPU, 16GB RAM, 300GB)
├── DevOps VM        (4 vCPU, 16GB RAM, 150GB)
├── Monitoring VM    (2 vCPU, 8GB RAM, 100GB)
└── Productivity VM  (4 vCPU, 12GB RAM, 150GB)
```

## Quick Start

### 1. Terraform - Provision VMs on ESXi
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your ESXi credentials
terraform init
terraform plan
terraform apply
```

### 2. Ansible - Configure VMs
```bash
cd ansible
# Update inventory/hosts.ini with VM IPs
ansible-playbook -i inventory/hosts.ini site.yml
```

### 3. Kubernetes - Deploy Services
```bash
cd kubernetes
kubectl apply -f manifests/
```

### 4. Docker Compose - Standalone Services
```bash
cd docker-compose/ollama && docker compose up -d
cd docker-compose/monitoring && docker compose up -d
```

## Services

| Service | Purpose | Access |
|---------|---------|--------|
| Ollama + Open WebUI | Local AI/LLMs | http://ai.local |
| GitLab CE | Git + CI/CD | http://gitlab.local |
| Nextcloud | File sync + Office | http://cloud.local |
| WikiJS | Knowledge base | http://wiki.local |
| Grafana | Dashboards | http://grafana.local |
| Prometheus | Metrics | http://prometheus.local |
| Uptime Kuma | Uptime monitoring | http://status.local |
| Portainer | Container management | http://portainer.local |
| PostgreSQL | Database | port 5432 |
| Redis | Cache | port 6379 |
