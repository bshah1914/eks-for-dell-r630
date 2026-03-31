#!/usr/bin/env python3
"""Set up SSH key access on all VMs via VMware guest operations."""
import subprocess
import os
import sys
import tempfile

GOVC = r"C:\Users\dell\bin\govc.exe"
SSH_PUBKEY = open(os.path.expanduser("~/.ssh/id_rsa.pub")).read().strip()

ENV = os.environ.copy()
ENV.update({
    "GOVC_URL": "https://192.168.50.163",
    "GOVC_USERNAME": "root",
    "GOVC_PASSWORD": "Admin@123$",
    "GOVC_INSECURE": "true",
})

CRED = "ubuntu:Admin@123$"

VMS = ["k8s-master", "k8s-worker-1", "k8s-worker-2", "ollama-ai",
       "database", "devops", "monitoring", "productivity"]


def govc_run(vm_name, *args):
    cmd = [GOVC, "guest.run", "-vm", vm_name, "-l", CRED] + list(args)
    r = subprocess.run(cmd, env=ENV, capture_output=True, text=True, timeout=30)
    return r.returncode, r.stdout.strip(), r.stderr.strip()


def govc_upload(vm_name, local_path, remote_path):
    cmd = [GOVC, "guest.upload", "-vm", vm_name, "-l", CRED, "-f", local_path, remote_path]
    r = subprocess.run(cmd, env=ENV, capture_output=True, text=True, timeout=30)
    return r.returncode, r.stdout.strip(), r.stderr.strip()


def setup_vm(vm_name):
    print(f"\n=== {vm_name} ===")

    # Test connectivity
    rc, out, err = govc_run(vm_name, "/usr/bin/whoami")
    if rc != 0:
        print(f"  ERROR: can't reach VM: {err}")
        return False
    print(f"  Connected as: {out}")

    # Create .ssh directory
    rc, _, _ = govc_run(vm_name, "/bin/mkdir", "-p", "/home/ubuntu/.ssh")
    rc, _, _ = govc_run(vm_name, "/bin/chmod", "700", "/home/ubuntu/.ssh")

    # Write SSH key to a temp file and upload
    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
        f.write(SSH_PUBKEY + "\n")
        tmp_path = f.name

    rc, out, err = govc_upload(vm_name, tmp_path, "/home/ubuntu/.ssh/authorized_keys")
    os.unlink(tmp_path)
    if rc != 0:
        print(f"  ERROR uploading key: {err}")
        return False

    # Fix permissions
    govc_run(vm_name, "/bin/chmod", "600", "/home/ubuntu/.ssh/authorized_keys")
    govc_run(vm_name, "/bin/chown", "-R", "ubuntu:ubuntu", "/home/ubuntu/.ssh")

    # Create a setup script to enable SSH password auth
    setup_script = """#!/bin/bash
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
"""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".sh", delete=False) as f:
        f.write(setup_script)
        script_path = f.name

    govc_upload(vm_name, script_path, "/tmp/fix-ssh.sh")
    os.unlink(script_path)
    govc_run(vm_name, "/bin/chmod", "+x", "/tmp/fix-ssh.sh")
    govc_run(vm_name, "/usr/bin/sudo", "/tmp/fix-ssh.sh")

    # Verify key exists
    rc, out, _ = govc_run(vm_name, "/usr/bin/head", "-c", "20", "/home/ubuntu/.ssh/authorized_keys")
    if "ssh-rsa" in out:
        print(f"  SSH key installed + sshd configured!")
        return True
    else:
        print(f"  WARN: key verification unclear: {out}")
        return False


if __name__ == "__main__":
    vms = sys.argv[1:] if len(sys.argv) > 1 else VMS
    results = {}
    for vm in vms:
        results[vm] = setup_vm(vm)

    print("\n=== Results ===")
    for vm, ok in results.items():
        print(f"  {vm}: {'OK' if ok else 'FAILED'}")
