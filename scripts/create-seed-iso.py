#!/usr/bin/env python3
"""
Create cloud-init seed ISOs for each VM and upload to ESXi datastore.
Uses pycdlib to create ISO9660 images with cloud-init nocloud datasource.
"""

import subprocess
import sys
import os
import tempfile

# Install pycdlib if not present
try:
    import pycdlib
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pycdlib"])
    import pycdlib

GOVC = r"C:\Users\dell\bin\govc.exe"
DS = "datastore1"

ENV = os.environ.copy()
ENV.update({
    "GOVC_URL": "https://192.168.50.163",
    "GOVC_USERNAME": "root",
    "GOVC_PASSWORD": "Admin@123$",
    "GOVC_INSECURE": "true",
})

VMS = {
    "k8s-master":   {"ip": "192.168.50.10", "cpu": 2, "ram": "4GB"},
    "k8s-worker-1": {"ip": "192.168.50.11", "cpu": 4, "ram": "24GB"},
    "k8s-worker-2": {"ip": "192.168.50.12", "cpu": 4, "ram": "24GB"},
    "ollama-ai":    {"ip": "192.168.50.20", "cpu": 4, "ram": "64GB"},
    "database":     {"ip": "192.168.50.30", "cpu": 2, "ram": "16GB"},
    "devops":       {"ip": "192.168.50.40", "cpu": 2, "ram": "12GB"},
    "monitoring":   {"ip": "192.168.50.50", "cpu": 1, "ram": "4GB"},
    "productivity": {"ip": "192.168.50.60", "cpu": 2, "ram": "8GB"},
}

GATEWAY = "192.168.50.1"
DNS = "8.8.8.8"
PASSWORD = "Admin@123$"


def make_userdata(vm_name):
    return f"""#cloud-config
hostname: {vm_name}
manage_etc_hosts: true
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: "{PASSWORD}"
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/twe8JDu79VmUvZd2IzOBpT7YkFS6FpcNIShTmVCfRJCUTB92wwcrVk9EMcfJEC0y8BVcRaYzOSUdwggaPbcsj8Ji9dBmxuN02TiugtysxDcqf3LhGAdNhAjF3i5K6WR1HpWv3Es7JSkpk82kUFSo4SBEZEg2QEP4kzRnSl5MJk9wFglmNE34ETZT6SqPoEm0xrqg8X4kq+1MiucVBdLJmpSCG7BKRYpfj+Xg9mLqGG+sRlACiKu1jEssdpBmn19OpnsgH1YNpywUGMyrTaKGPBm6FRSxu3DYZ0EzBAjnHTJprshEFIKE9knAbsXWEv5dWUgm0eRhbswXnnGrIM6sKm+/SXYuQL2+qb02gVpMmhh1Erqh0NUgUbwRKus/xwsGZ2WKx1ow8OMUrxM/rouvET54BieHWciFsmx1yTFCjzYvQCTRowhdJVzi181nPhiaeUThTLgvCM3C/3EnUU9OUrzxUEjZnleI9oH4YBcLKoie1C0DsceO52uKglcBrl+NFtoGTF0sOoeXt8HR3Hkt2yLBu1pN/MgfuQHaIdShX2KDaNqF02sFginYzfdlP5AIdHcily7GGv2h4vdCYjUwu4xLedpa6L15uD8uj3ZZP577sKh7Xpv/bEH9Pzr0gU0zvA6XNUR9ADXrnB0Lt4mg1O6C+Pn6hXuTanIkL5Q2bw== dell@DESKTOP-M9SG0C6
chpasswd:
  expire: false
ssh_pwauth: true
package_update: true
package_upgrade: true
packages:
  - curl
  - wget
  - vim
  - htop
  - net-tools
  - gnupg
  - ca-certificates
  - apt-transport-https
  - software-properties-common
  - open-vm-tools
  - qemu-guest-agent
  - jq
  - unzip
runcmd:
  - systemctl enable open-vm-tools
  - systemctl start open-vm-tools
  - systemctl enable ssh
  - systemctl start ssh
"""


def make_metadata(vm_name, ip):
    return f"""instance-id: {vm_name}
local-hostname: {vm_name}
network-interfaces: |
  auto ens192
  iface ens192 inet static
  address {ip}
  netmask 255.255.255.0
  gateway {GATEWAY}
  dns-nameservers {DNS}
"""


def make_network_config(ip):
    return f"""version: 2
ethernets:
  ens192:
    dhcp4: false
    addresses:
      - {ip}/24
    gateway4: {GATEWAY}
    nameservers:
      addresses:
        - {DNS}
        - 8.8.4.4
"""


def create_seed_iso(vm_name, ip, output_path):
    """Create a cloud-init nocloud seed ISO."""
    iso = pycdlib.PyCdlib()
    iso.new(
        interchange_level=3,
        joliet=True,
        vol_ident="cidata",
    )

    userdata = make_userdata(vm_name).encode("utf-8")
    metadata = make_metadata(vm_name, ip).encode("utf-8")
    network_config = make_network_config(ip).encode("utf-8")

    iso.add_fp(
        fp=__import__("io").BytesIO(userdata),
        length=len(userdata),
        iso_path="/USER_DATA.;1",
        joliet_path="/user-data",
    )
    iso.add_fp(
        fp=__import__("io").BytesIO(metadata),
        length=len(metadata),
        iso_path="/META_DATA.;1",
        joliet_path="/meta-data",
    )
    iso.add_fp(
        fp=__import__("io").BytesIO(network_config),
        length=len(network_config),
        iso_path="/NETWORK_.;1",
        joliet_path="/network-config",
    )

    iso.write(output_path)
    iso.close()
    print(f"  Created ISO: {output_path}")


def upload_and_attach(vm_name, iso_path):
    """Upload seed ISO to datastore and attach to VM."""
    remote_path = f"{vm_name}/{vm_name}-seed.iso"

    # Remove old ISO if exists, then upload
    print(f"  Uploading to datastore...")
    subprocess.run(
        [GOVC, "datastore.rm", f"-ds={DS}", remote_path],
        env=ENV, capture_output=True,
    )
    result = subprocess.run(
        [GOVC, "datastore.upload", f"-ds={DS}", iso_path, remote_path],
        env=ENV, capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"  Upload error: {result.stderr}")
        raise Exception(f"Upload failed for {vm_name}")

    # Power off VM first
    print(f"  Powering off {vm_name}...")
    subprocess.run(
        [GOVC, "vm.power", "-off", "-force", vm_name],
        env=ENV, capture_output=True,
    )

    import time
    time.sleep(3)

    # Add CD-ROM and insert ISO
    print(f"  Attaching seed ISO...")
    # Try to add cdrom (might already exist)
    result = subprocess.run(
        [GOVC, "device.cdrom.add", f"-vm={vm_name}"],
        env=ENV, capture_output=True, text=True,
    )
    cdrom_name = result.stdout.strip() if result.returncode == 0 else "cdrom-3000"

    subprocess.run(
        [GOVC, "device.cdrom.insert", f"-vm={vm_name}", f"-ds={DS}", f"-device={cdrom_name}", remote_path],
        env=ENV, check=True, capture_output=True,
    )

    # Power on
    print(f"  Powering on {vm_name}...")
    subprocess.run(
        [GOVC, "vm.power", "-on", vm_name],
        env=ENV, check=True, capture_output=True,
    )
    print(f"  {vm_name} is booting with cloud-init!")


def main():
    print("=== Creating Cloud-Init Seed ISOs ===\n")

    with tempfile.TemporaryDirectory() as tmpdir:
        for vm_name, config in VMS.items():
            print(f"\n--- {vm_name} (IP: {config['ip']}) ---")
            iso_path = os.path.join(tmpdir, f"{vm_name}-seed.iso")
            create_seed_iso(vm_name, config["ip"], iso_path)
            upload_and_attach(vm_name, iso_path)

    print("\n=== All VMs booting with Ubuntu + cloud-init! ===")
    print("Wait 3-5 minutes for cloud-init to complete, then SSH:")
    print()
    for vm_name, config in VMS.items():
        print(f"  ssh ubuntu@{config['ip']}  # password: {PASSWORD}")


if __name__ == "__main__":
    main()
