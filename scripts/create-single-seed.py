#!/usr/bin/env python3
"""Create and upload a cloud-init seed ISO for a single VM."""

import subprocess
import sys
import os
import io
import tempfile

import pycdlib

GOVC = r"C:\Users\dell\bin\govc.exe"
DS = "datastore1"
SSH_PUBKEY = open(os.path.expanduser("~/.ssh/id_rsa.pub")).read().strip()

ENV = os.environ.copy()
ENV.update({
    "GOVC_URL": "https://192.168.50.163",
    "GOVC_USERNAME": "root",
    "GOVC_PASSWORD": "Admin@123$",
    "GOVC_INSECURE": "true",
})

GATEWAY = "192.168.50.1"
PASSWORD = "Admin@123$"


def create_and_deploy(vm_name, ip):
    print(f"\n=== {vm_name} ({ip}) ===")

    userdata = f"""#cloud-config
hostname: {vm_name}
manage_etc_hosts: true
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: "{PASSWORD}"
    ssh_authorized_keys:
      - {SSH_PUBKEY}
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
  - open-vm-tools
  - jq
  - unzip
runcmd:
  - systemctl enable open-vm-tools
  - systemctl start open-vm-tools
  - systemctl enable ssh
  - systemctl start ssh
""".encode("utf-8")

    metadata = f"""instance-id: {vm_name}
local-hostname: {vm_name}
network-interfaces: |
  auto ens192
  iface ens192 inet static
  address {ip}
  netmask 255.255.255.0
  gateway {GATEWAY}
  dns-nameservers 8.8.8.8
""".encode("utf-8")

    network_config = f"""version: 2
ethernets:
  ens192:
    dhcp4: false
    addresses:
      - {ip}/24
    gateway4: {GATEWAY}
    nameservers:
      addresses:
        - 8.8.8.8
        - 8.8.4.4
""".encode("utf-8")

    # Create ISO
    with tempfile.NamedTemporaryFile(suffix=".iso", delete=False) as f:
        iso_path = f.name

    iso = pycdlib.PyCdlib()
    iso.new(interchange_level=3, joliet=True, vol_ident="cidata")

    iso.add_fp(io.BytesIO(userdata), len(userdata),
               iso_path="/USER_DATA.;1", joliet_path="/user-data")
    iso.add_fp(io.BytesIO(metadata), len(metadata),
               iso_path="/META_DATA.;1", joliet_path="/meta-data")
    iso.add_fp(io.BytesIO(network_config), len(network_config),
               iso_path="/NETWORK_.;1", joliet_path="/network-config")

    iso.write(iso_path)
    iso.close()
    print(f"  ISO created")

    # Upload
    remote_path = f"{vm_name}/{vm_name}-seed.iso"
    print(f"  Uploading...")
    r = subprocess.run(
        [GOVC, "datastore.upload", f"-ds={DS}", iso_path, remote_path],
        env=ENV, capture_output=True, text=True,
    )
    os.unlink(iso_path)
    if r.returncode != 0:
        print(f"  ERROR: {r.stderr}")
        return False

    # Attach CD
    print(f"  Attaching ISO...")
    subprocess.run(
        [GOVC, "device.cdrom.insert", f"-vm={vm_name}", f"-ds={DS}", remote_path],
        env=ENV, capture_output=True,
    )

    # Power on
    print(f"  Powering on...")
    subprocess.run([GOVC, "vm.power", "-on", vm_name], env=ENV, capture_output=True)
    print(f"  {vm_name} booting!")
    return True


if __name__ == "__main__":
    vm_name = sys.argv[1]
    ip = sys.argv[2]
    create_and_deploy(vm_name, ip)
