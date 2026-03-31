#!/bin/bash
set -euo pipefail

# Attach Ubuntu cloud image VMDK to all VMs
# This copies the template disk to each VM and makes it bootable

export GOVC_URL="https://192.168.50.163"
export GOVC_USERNAME="root"
export GOVC_PASSWORD='Admin@123$'
export GOVC_INSECURE=true

GOVC="/c/Users/dell/bin/govc.exe"
TEMPLATE_VMDK="ubuntu-2204-template/ubuntu-2204-template.vmdk"
DS="datastore1"

VMS=("k8s-master" "k8s-worker-1" "k8s-worker-2" "ollama-ai" "database" "devops" "monitoring" "productivity")

for VM in "${VMS[@]}"; do
    echo "=== Processing $VM ==="

    # Power off VM
    echo "  Powering off $VM..."
    $GOVC vm.power -off -force "$VM" 2>/dev/null || true
    sleep 2

    # Remove the empty disk that Terraform created
    echo "  Removing empty disk..."
    $GOVC device.remove -vm "$VM" disk-1000-0 2>/dev/null || true

    # Copy template VMDK to VM folder
    echo "  Copying OS disk to $VM..."
    $GOVC datastore.cp -ds="$DS" "$TEMPLATE_VMDK" "$VM/$VM-os.vmdk" 2>/dev/null || echo "  (disk may already exist, continuing...)"

    # Attach the copied VMDK
    echo "  Attaching OS disk..."
    $GOVC vm.disk.attach -vm "$VM" -ds="$DS" -disk="$VM/$VM-os.vmdk" -link=false -controller=pvscsi-1000 2>/dev/null || \
    $GOVC vm.disk.attach -vm "$VM" -ds="$DS" -disk="$VM/$VM-os.vmdk" -link=false 2>/dev/null

    # Set boot order to disk
    echo "  Setting boot order..."
    $GOVC device.boot -vm "$VM" -order disk 2>/dev/null || true

    echo "  Done with $VM!"
    echo ""
done

echo "=== All disks attached! Powering on VMs ==="
for VM in "${VMS[@]}"; do
    echo "  Starting $VM..."
    $GOVC vm.power -on "$VM" 2>/dev/null || true
done

echo ""
echo "=== Complete! All VMs booting Ubuntu ==="
echo "Wait 2-3 minutes for VMs to boot, then check IPs with:"
echo "  govc vm.info 'k8s-*' 'ollama-*' database devops monitoring productivity"
