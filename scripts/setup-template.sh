#!/bin/bash
set -euo pipefail

# Create Ubuntu 22.04 VM template on ESXi
# Run this BEFORE terraform to create the base template

echo "=== Ubuntu 22.04 Template Setup Guide ==="
echo ""
echo "1. Download Ubuntu 22.04 Server ISO:"
echo "   https://releases.ubuntu.com/22.04/ubuntu-22.04.4-live-server-amd64.iso"
echo ""
echo "2. Upload ISO to ESXi datastore via vSphere web client"
echo ""
echo "3. Create a new VM in ESXi:"
echo "   - Name: ubuntu-2204-template"
echo "   - Guest OS: Ubuntu Linux (64-bit)"
echo "   - CPU: 2, RAM: 4GB, Disk: 40GB thin"
echo "   - Mount the ISO"
echo ""
echo "4. Install Ubuntu with these settings:"
echo "   - Minimal install"
echo "   - Enable OpenSSH server"
echo "   - Username: ubuntu"
echo "   - Set a password"
echo ""
echo "5. After install, run inside the VM:"
echo ""
cat << 'SCRIPT'
# Update system
sudo apt update && sudo apt upgrade -y

# Install cloud-init and open-vm-tools
sudo apt install -y cloud-init open-vm-tools perl

# Install common packages
sudo apt install -y curl wget vim htop net-tools gnupg ca-certificates \
    apt-transport-https software-properties-common

# Enable password-less sudo
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ubuntu

# Setup SSH key access
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# Add your public key:
# echo "ssh-rsa YOUR_PUBLIC_KEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Clean up for template
sudo cloud-init clean
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo apt clean
sudo rm -rf /tmp/*

# Shutdown
sudo shutdown -h now
SCRIPT

echo ""
echo "6. In ESXi, right-click the VM -> Template -> Convert to Template"
echo ""
echo "7. Now you can run 'terraform apply' to clone this template!"
