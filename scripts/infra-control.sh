#!/bin/bash
set -euo pipefail

# ============================================================
#  Dell R630 Homelab — Start/Stop/Status Control
#  Usage: ./infra-control.sh {start|stop|status|restart}
# ============================================================

export GOVC_URL="https://192.168.50.163"
export GOVC_USERNAME="root"
export GOVC_PASSWORD='Admin@123$'
export GOVC_INSECURE=true
GOVC="/c/Users/dell/bin/govc.exe"

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/id_rsa"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Boot order: database first, then K8s, then services
START_ORDER=("database" "k8s-master" "k8s-worker-1" "k8s-worker-2" "monitoring" "ollama-ai" "devops" "productivity")
# Stop order: reverse
STOP_ORDER=("productivity" "devops" "ollama-ai" "monitoring" "k8s-worker-2" "k8s-worker-1" "k8s-master" "database")

VM_IPS=(
    "database:192.168.50.30"
    "k8s-master:192.168.50.10"
    "k8s-worker-1:192.168.50.11"
    "k8s-worker-2:192.168.50.12"
    "monitoring:192.168.50.50"
    "ollama-ai:192.168.50.20"
    "devops:192.168.50.40"
    "productivity:192.168.50.60"
)

get_ip() {
    for entry in "${VM_IPS[@]}"; do
        if [[ "$entry" == "$1:"* ]]; then
            echo "${entry#*:}"
            return
        fi
    done
}

# ============================================================
#  START — Power on all VMs in order
# ============================================================
start_infra() {
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  STARTING DELL R630 HOMELAB${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""

    for VM in "${START_ORDER[@]}"; do
        STATE=$($GOVC vm.info "$VM" 2>/dev/null | grep "Power state" | awk '{print $NF}')
        if [[ "$STATE" == "poweredOn" ]]; then
            echo -e "  ${BLUE}[SKIP]${NC} $VM — already running"
        else
            echo -ne "  ${YELLOW}[START]${NC} $VM — powering on..."
            $GOVC vm.power -on "$VM" 2>/dev/null
            echo -e " ${GREEN}done${NC}"

            # Wait between VMs
            if [[ "$VM" == "database" || "$VM" == "k8s-master" ]]; then
                echo -e "  ${YELLOW}       waiting 30s for $VM to initialize...${NC}"
                sleep 30
            else
                sleep 10
            fi
        fi
    done

    echo ""
    echo -e "${GREEN}All VMs started! Services will auto-start via Docker/K8s.${NC}"
    echo -e "Wait 2-3 minutes for all services to be ready."
    echo ""
    echo "Run './infra-control.sh status' to check."
}

# ============================================================
#  STOP — Gracefully shutdown all VMs
# ============================================================
stop_infra() {
    echo -e "${RED}============================================${NC}"
    echo -e "${RED}  STOPPING DELL R630 HOMELAB${NC}"
    echo -e "${RED}============================================${NC}"
    echo ""

    for VM in "${STOP_ORDER[@]}"; do
        STATE=$($GOVC vm.info "$VM" 2>/dev/null | grep "Power state" | awk '{print $NF}')
        if [[ "$STATE" == "poweredOff" ]]; then
            echo -e "  ${BLUE}[SKIP]${NC} $VM — already off"
        else
            IP=$(get_ip "$VM")
            echo -ne "  ${RED}[STOP]${NC} $VM ($IP) — shutting down..."

            # Try graceful shutdown via SSH first
            ssh $SSH_OPTS ubuntu@$IP "sudo shutdown -h now" 2>/dev/null || true

            # Wait for VM to power off
            for i in $(seq 1 12); do
                sleep 5
                STATE=$($GOVC vm.info "$VM" 2>/dev/null | grep "Power state" | awk '{print $NF}')
                if [[ "$STATE" == "poweredOff" ]]; then
                    echo -e " ${GREEN}done${NC}"
                    break
                fi
                if [[ $i -eq 12 ]]; then
                    echo -ne " forcing..."
                    $GOVC vm.power -off "$VM" 2>/dev/null || true
                    echo -e " ${YELLOW}forced off${NC}"
                fi
            done
        fi
    done

    echo ""
    echo -e "${RED}All VMs stopped.${NC}"
}

# ============================================================
#  STATUS — Check all VMs and services
# ============================================================
check_status() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  DELL R630 HOMELAB STATUS${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""

    echo -e "${BLUE}── VM Status ──${NC}"
    printf "  %-18s %-18s %-12s %s\n" "VM" "IP" "POWER" "SSH"
    echo "  ──────────────────────────────────────────────────────────"

    for entry in "${VM_IPS[@]}"; do
        VM="${entry%%:*}"
        IP="${entry#*:}"

        # Power state
        STATE=$($GOVC vm.info "$VM" 2>/dev/null | grep "Power state" | awk '{print $NF}')
        if [[ "$STATE" == "poweredOn" ]]; then
            POWER="${GREEN}ON${NC}"
        else
            POWER="${RED}OFF${NC}"
        fi

        # SSH check
        if [[ "$STATE" == "poweredOn" ]]; then
            if ssh $SSH_OPTS ubuntu@$IP "echo ok" 2>/dev/null | grep -q ok; then
                SSH_STATUS="${GREEN}OK${NC}"
            else
                SSH_STATUS="${YELLOW}WAIT${NC}"
            fi
        else
            SSH_STATUS="${RED}—${NC}"
        fi

        printf "  %-18s %-18s " "$VM" "$IP"
        echo -e "$POWER\t   $SSH_STATUS"
    done

    echo ""
    echo -e "${BLUE}── Services ──${NC}"
    printf "  %-22s %-30s %s\n" "SERVICE" "URL" "STATUS"
    echo "  ──────────────────────────────────────────────────────────────"

    # Check each service
    SERVICES=(
        "Ollama AI Chat:http://192.168.50.20:3000"
        "GitLab:http://192.168.50.40"
        "Nextcloud:http://192.168.50.60"
        "Grafana:http://192.168.50.50:3000"
        "Prometheus:http://192.168.50.50:9090"
        "Uptime Kuma:http://192.168.50.50:3001"
        "CloudSentinel (K8s):http://192.168.50.11:30001"
        "AWS Cost Bot (K8s):http://192.168.50.11:30003"
    )

    for entry in "${SERVICES[@]}"; do
        NAME="${entry%%:*}"
        # Handle URLs with colons properly
        URL="${entry#*:}"

        HTTP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$URL" 2>/dev/null || echo "000")
        if [[ "$HTTP" == "000" ]]; then
            STATUS="${RED}DOWN${NC}"
        elif [[ "$HTTP" =~ ^(200|302|301)$ ]]; then
            STATUS="${GREEN}UP ($HTTP)${NC}"
        else
            STATUS="${YELLOW}$HTTP${NC}"
        fi

        printf "  %-22s %-30s " "$NAME" "$URL"
        echo -e "$STATUS"
    done

    # K8s cluster
    echo ""
    echo -e "${BLUE}── Kubernetes Cluster ──${NC}"
    ssh $SSH_OPTS ubuntu@192.168.50.10 "kubectl get nodes 2>/dev/null" 2>/dev/null | sed 's/^/  /' || echo -e "  ${RED}K8s master not reachable${NC}"

    echo ""
    echo -e "${BLUE}── K8s Pods ──${NC}"
    ssh $SSH_OPTS ubuntu@192.168.50.10 "kubectl get pods -A --field-selector=metadata.namespace!=kube-system,metadata.namespace!=kube-flannel 2>/dev/null" 2>/dev/null | sed 's/^/  /' || echo -e "  ${RED}Cannot reach cluster${NC}"

    echo ""
    echo -e "${BLUE}── Database ──${NC}"
    ssh $SSH_OPTS ubuntu@192.168.50.30 "docker ps --format '  {{.Names}}: {{.Status}}' 2>/dev/null" 2>/dev/null || echo -e "  ${RED}Database VM not reachable${NC}"
}

# ============================================================
#  RESTART
# ============================================================
restart_infra() {
    stop_infra
    echo ""
    echo "Waiting 10s before starting..."
    sleep 10
    start_infra
}

# ============================================================
#  MAIN
# ============================================================
case "${1:-}" in
    start)   start_infra ;;
    stop)    stop_infra ;;
    status)  check_status ;;
    restart) restart_infra ;;
    *)
        echo "Dell R630 Homelab Control"
        echo ""
        echo "Usage: $0 {start|stop|status|restart}"
        echo ""
        echo "  start   — Power on all VMs in order (DB → K8s → Services)"
        echo "  stop    — Gracefully shutdown all VMs"
        echo "  status  — Check all VMs, services, K8s cluster"
        echo "  restart — Stop then start everything"
        ;;
esac
