#!/usr/bin/env python3
"""Create comprehensive Grafana dashboards for Dell R630 Homelab."""
import json
import subprocess
import os

SSH_OPTS = "-o StrictHostKeyChecking=no -i ~/.ssh/id_rsa"
GRAFANA_URL = "http://admin:admin@localhost:3000"

def grafana_api(endpoint, data):
    """Call Grafana API via SSH to monitoring VM."""
    payload = json.dumps(data).replace('"', '\\"')
    cmd = f'ssh {SSH_OPTS} ubuntu@192.168.50.50 \'curl -s -X POST {GRAFANA_URL}{endpoint} -H "Content-Type: application/json" -d "{payload}"\''
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=15)
    return r.stdout

# ============================================================
# DASHBOARD 1: Homelab Overview
# ============================================================
homelab_dashboard = {
    "dashboard": {
        "id": None,
        "uid": "homelab-overview",
        "title": "Dell R630 Homelab - Overview",
        "tags": ["homelab", "overview"],
        "timezone": "browser",
        "refresh": "30s",
        "time": {"from": "now-1h", "to": "now"},
        "panels": [
            # Row 1: Stats
            {
                "id": 1, "type": "stat", "title": "Total VMs",
                "gridPos": {"h": 4, "w": 3, "x": 0, "y": 0},
                "targets": [{"expr": "count(up{job=\"node-exporter\"})", "refId": "A"}],
                "fieldConfig": {"defaults": {"thresholds": {"steps": [{"color": "green", "value": None}]}}}
            },
            {
                "id": 2, "type": "stat", "title": "VMs Online",
                "gridPos": {"h": 4, "w": 3, "x": 3, "y": 0},
                "targets": [{"expr": "count(up{job=\"node-exporter\"} == 1)", "refId": "A"}],
                "fieldConfig": {"defaults": {"thresholds": {"steps": [{"color": "red", "value": None}, {"color": "green", "value": 8}]}}}
            },
            {
                "id": 3, "type": "stat", "title": "Avg CPU Usage",
                "gridPos": {"h": 4, "w": 3, "x": 6, "y": 0},
                "targets": [{"expr": "avg(100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100))", "refId": "A"}],
                "fieldConfig": {"defaults": {"unit": "percent", "thresholds": {"steps": [{"color": "green", "value": None}, {"color": "yellow", "value": 60}, {"color": "red", "value": 85}]}}}
            },
            {
                "id": 4, "type": "stat", "title": "Avg Memory Usage",
                "gridPos": {"h": 4, "w": 3, "x": 9, "y": 0},
                "targets": [{"expr": "avg((1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100)", "refId": "A"}],
                "fieldConfig": {"defaults": {"unit": "percent", "thresholds": {"steps": [{"color": "green", "value": None}, {"color": "yellow", "value": 70}, {"color": "red", "value": 90}]}}}
            },
            {
                "id": 5, "type": "stat", "title": "Total RAM",
                "gridPos": {"h": 4, "w": 3, "x": 12, "y": 0},
                "targets": [{"expr": "sum(node_memory_MemTotal_bytes)", "refId": "A"}],
                "fieldConfig": {"defaults": {"unit": "bytes", "thresholds": {"steps": [{"color": "blue", "value": None}]}}}
            },
            {
                "id": 6, "type": "stat", "title": "Total Disk",
                "gridPos": {"h": 4, "w": 3, "x": 15, "y": 0},
                "targets": [{"expr": "sum(node_filesystem_size_bytes{mountpoint=\"/\"})", "refId": "A"}],
                "fieldConfig": {"defaults": {"unit": "bytes", "thresholds": {"steps": [{"color": "blue", "value": None}]}}}
            },
            {
                "id": 7, "type": "stat", "title": "Uptime (min)",
                "gridPos": {"h": 4, "w": 3, "x": 18, "y": 0},
                "targets": [{"expr": "min(node_time_seconds - node_boot_time_seconds)", "refId": "A"}],
                "fieldConfig": {"defaults": {"unit": "s", "thresholds": {"steps": [{"color": "green", "value": None}]}}}
            },
            {
                "id": 8, "type": "stat", "title": "Prometheus Targets",
                "gridPos": {"h": 4, "w": 3, "x": 21, "y": 0},
                "targets": [{"expr": "count(up)", "refId": "A"}],
                "fieldConfig": {"defaults": {"thresholds": {"steps": [{"color": "purple", "value": None}]}}}
            },
            # Row 2: CPU per VM
            {
                "id": 10, "type": "timeseries", "title": "CPU Usage per VM",
                "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
                "targets": [{"expr": "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)", "legendFormat": "{{instance}}", "refId": "A"}],
                "fieldConfig": {"defaults": {"unit": "percent", "min": 0, "max": 100, "custom": {"fillOpacity": 10}}}
            },
            # Row 2: Memory per VM
            {
                "id": 11, "type": "timeseries", "title": "Memory Usage per VM",
                "gridPos": {"h": 8, "w": 12, "x": 12, "y": 4},
                "targets": [{"expr": "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100", "legendFormat": "{{instance}}", "refId": "A"}],
                "fieldConfig": {"defaults": {"unit": "percent", "min": 0, "max": 100, "custom": {"fillOpacity": 10}}}
            },
            # Row 3: Disk Usage
            {
                "id": 12, "type": "bargauge", "title": "Disk Usage per VM",
                "gridPos": {"h": 8, "w": 12, "x": 0, "y": 12},
                "targets": [{"expr": "(1 - node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"}) * 100", "legendFormat": "{{instance}}", "refId": "A"}],
                "fieldConfig": {"defaults": {"unit": "percent", "min": 0, "max": 100, "thresholds": {"steps": [{"color": "green", "value": None}, {"color": "yellow", "value": 70}, {"color": "red", "value": 90}]}}}
            },
            # Row 3: Network Traffic
            {
                "id": 13, "type": "timeseries", "title": "Network Traffic (all VMs)",
                "gridPos": {"h": 8, "w": 12, "x": 12, "y": 12},
                "targets": [
                    {"expr": "sum(rate(node_network_receive_bytes_total{device!~\"lo|veth.*|docker.*|flannel.*|cni.*\"}[5m]))", "legendFormat": "Received", "refId": "A"},
                    {"expr": "sum(rate(node_network_transmit_bytes_total{device!~\"lo|veth.*|docker.*|flannel.*|cni.*\"}[5m]))", "legendFormat": "Transmitted", "refId": "B"}
                ],
                "fieldConfig": {"defaults": {"unit": "Bps", "custom": {"fillOpacity": 20}}}
            },
            # Row 4: Service Status Table
            {
                "id": 14, "type": "table", "title": "VM Status",
                "gridPos": {"h": 8, "w": 24, "x": 0, "y": 20},
                "targets": [
                    {"expr": "node_uname_info", "format": "table", "instant": True, "refId": "A"},
                ],
                "transformations": [
                    {"id": "organize", "options": {"excludeByName": {"Time": True, "__name__": True, "domainname": True, "job": True}, "renameByName": {"instance": "VM", "nodename": "Hostname", "release": "Kernel", "sysname": "OS"}}}
                ]
            }
        ],
        "templating": {"list": []},
        "annotations": {"list": []},
        "schemaVersion": 39
    },
    "overwrite": True,
    "folderId": 0
}

# ============================================================
# DASHBOARD 2: Services Health
# ============================================================
services_dashboard = {
    "dashboard": {
        "id": None,
        "uid": "homelab-services",
        "title": "Dell R630 Homelab - Services Health",
        "tags": ["homelab", "services"],
        "timezone": "browser",
        "refresh": "30s",
        "time": {"from": "now-1h", "to": "now"},
        "panels": [
            # Service Status Indicators
            {
                "id": 1, "type": "stat", "title": "K8s Master",
                "gridPos": {"h": 3, "w": 3, "x": 0, "y": 0},
                "targets": [{"expr": "up{instance=\"192.168.50.10:9100\"}", "refId": "A"}],
                "fieldConfig": {"defaults": {"mappings": [{"type": "value", "options": {"0": {"text": "DOWN", "color": "red"}, "1": {"text": "UP", "color": "green"}}}], "thresholds": {"steps": [{"color": "red", "value": None}, {"color": "green", "value": 1}]}}}
            },
            {
                "id": 2, "type": "stat", "title": "K8s Worker 1",
                "gridPos": {"h": 3, "w": 3, "x": 3, "y": 0},
                "targets": [{"expr": "up{instance=\"192.168.50.11:9100\"}", "refId": "A"}],
                "fieldConfig": {"defaults": {"mappings": [{"type": "value", "options": {"0": {"text": "DOWN", "color": "red"}, "1": {"text": "UP", "color": "green"}}}], "thresholds": {"steps": [{"color": "red", "value": None}, {"color": "green", "value": 1}]}}}
            },
            {
                "id": 3, "type": "stat", "title": "K8s Worker 2",
                "gridPos": {"h": 3, "w": 3, "x": 6, "y": 0},
                "targets": [{"expr": "up{instance=\"192.168.50.12:9100\"}", "refId": "A"}],
                "fieldConfig": {"defaults": {"mappings": [{"type": "value", "options": {"0": {"text": "DOWN", "color": "red"}, "1": {"text": "UP", "color": "green"}}}], "thresholds": {"steps": [{"color": "red", "value": None}, {"color": "green", "value": 1}]}}}
            },
            {
                "id": 4, "type": "stat", "title": "Ollama AI",
                "gridPos": {"h": 3, "w": 3, "x": 9, "y": 0},
                "targets": [{"expr": "up{instance=\"192.168.50.20:9100\"}", "refId": "A"}],
                "fieldConfig": {"defaults": {"mappings": [{"type": "value", "options": {"0": {"text": "DOWN", "color": "red"}, "1": {"text": "UP", "color": "green"}}}], "thresholds": {"steps": [{"color": "red", "value": None}, {"color": "green", "value": 1}]}}}
            },
            {
                "id": 5, "type": "stat", "title": "Database",
                "gridPos": {"h": 3, "w": 3, "x": 12, "y": 0},
                "targets": [{"expr": "up{instance=\"192.168.50.30:9100\"}", "refId": "A"}],
                "fieldConfig": {"defaults": {"mappings": [{"type": "value", "options": {"0": {"text": "DOWN", "color": "red"}, "1": {"text": "UP", "color": "green"}}}], "thresholds": {"steps": [{"color": "red", "value": None}, {"color": "green", "value": 1}]}}}
            },
            {
                "id": 6, "type": "stat", "title": "GitLab",
                "gridPos": {"h": 3, "w": 3, "x": 15, "y": 0},
                "targets": [{"expr": "up{instance=\"192.168.50.40:9100\"}", "refId": "A"}],
                "fieldConfig": {"defaults": {"mappings": [{"type": "value", "options": {"0": {"text": "DOWN", "color": "red"}, "1": {"text": "UP", "color": "green"}}}], "thresholds": {"steps": [{"color": "red", "value": None}, {"color": "green", "value": 1}]}}}
            },
            {
                "id": 7, "type": "stat", "title": "Monitoring",
                "gridPos": {"h": 3, "w": 3, "x": 18, "y": 0},
                "targets": [{"expr": "up{instance=\"192.168.50.50:9100\"}", "refId": "A"}],
                "fieldConfig": {"defaults": {"mappings": [{"type": "value", "options": {"0": {"text": "DOWN", "color": "red"}, "1": {"text": "UP", "color": "green"}}}], "thresholds": {"steps": [{"color": "red", "value": None}, {"color": "green", "value": 1}]}}}
            },
            {
                "id": 8, "type": "stat", "title": "Productivity",
                "gridPos": {"h": 3, "w": 3, "x": 21, "y": 0},
                "targets": [{"expr": "up{instance=\"192.168.50.60:9100\"}", "refId": "A"}],
                "fieldConfig": {"defaults": {"mappings": [{"type": "value", "options": {"0": {"text": "DOWN", "color": "red"}, "1": {"text": "UP", "color": "green"}}}], "thresholds": {"steps": [{"color": "red", "value": None}, {"color": "green", "value": 1}]}}}
            },
            # Per-VM CPU + Memory
            {
                "id": 20, "type": "gauge", "title": "CPU Usage by VM",
                "gridPos": {"h": 8, "w": 12, "x": 0, "y": 3},
                "targets": [{"expr": "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)", "legendFormat": "{{instance}}", "refId": "A"}],
                "fieldConfig": {"defaults": {"unit": "percent", "min": 0, "max": 100, "thresholds": {"steps": [{"color": "green", "value": None}, {"color": "yellow", "value": 60}, {"color": "red", "value": 85}]}}}
            },
            {
                "id": 21, "type": "gauge", "title": "Memory Usage by VM",
                "gridPos": {"h": 8, "w": 12, "x": 12, "y": 3},
                "targets": [{"expr": "(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100", "legendFormat": "{{instance}}", "refId": "A"}],
                "fieldConfig": {"defaults": {"unit": "percent", "min": 0, "max": 100, "thresholds": {"steps": [{"color": "green", "value": None}, {"color": "yellow", "value": 70}, {"color": "red", "value": 90}]}}}
            },
            # Load Average
            {
                "id": 30, "type": "timeseries", "title": "Load Average (1m) per VM",
                "gridPos": {"h": 8, "w": 12, "x": 0, "y": 11},
                "targets": [{"expr": "node_load1", "legendFormat": "{{instance}}", "refId": "A"}],
                "fieldConfig": {"defaults": {"custom": {"fillOpacity": 10}}}
            },
            # Disk I/O
            {
                "id": 31, "type": "timeseries", "title": "Disk I/O per VM",
                "gridPos": {"h": 8, "w": 12, "x": 12, "y": 11},
                "targets": [
                    {"expr": "sum by(instance) (rate(node_disk_read_bytes_total[5m]))", "legendFormat": "Read {{instance}}", "refId": "A"},
                    {"expr": "sum by(instance) (rate(node_disk_written_bytes_total[5m]))", "legendFormat": "Write {{instance}}", "refId": "B"}
                ],
                "fieldConfig": {"defaults": {"unit": "Bps", "custom": {"fillOpacity": 10}}}
            }
        ],
        "templating": {"list": []},
        "annotations": {"list": []},
        "schemaVersion": 39
    },
    "overwrite": True,
    "folderId": 0
}

# Save dashboards to files and upload
for name, dashboard in [("overview", homelab_dashboard), ("services", services_dashboard)]:
    path = os.path.join(os.environ.get("TEMP", "C:/Users/dell/AppData/Local/Temp"), f"grafana-{name}.json")
    with open(path, "w") as f:
        json.dump(dashboard, f)
    print(f"Created {path}")

    # Upload via SSH
    r = subprocess.run(
        f'scp {SSH_OPTS} {path} ubuntu@192.168.50.50:/tmp/',
        shell=True, capture_output=True, text=True
    )
    r = subprocess.run(
        f'ssh {SSH_OPTS} ubuntu@192.168.50.50 \'curl -s -X POST http://admin:admin@localhost:3000/api/dashboards/db -H "Content-Type: application/json" -d @/tmp/grafana-{name}.json\'',
        shell=True, capture_output=True, text=True, timeout=15
    )
    print(f"  Upload result: {r.stdout[:100]}")

print("\nDone! Dashboards created.")
