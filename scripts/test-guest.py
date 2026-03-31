#!/usr/bin/env python3
"""Test VMware guest operations to access VMs directly."""
import subprocess
import os

GOVC = r"C:\Users\dell\bin\govc.exe"
ENV = os.environ.copy()
ENV.update({
    "GOVC_URL": "https://192.168.50.163",
    "GOVC_USERNAME": "root",
    "GOVC_PASSWORD": "Admin@123$",
    "GOVC_INSECURE": "true",
})

# Try different credential combos on k8s-master
creds = [
    "ubuntu:Admin@123$",
    "ubuntu:ubuntu",
    "root:root",
    "ubuntu:password",
]

for cred in creds:
    print(f"Trying {cred}...")
    r = subprocess.run(
        [GOVC, "guest.run", "-vm", "k8s-master", "-l", cred, "/usr/bin/whoami"],
        env=ENV, capture_output=True, text=True, timeout=10,
    )
    print(f"  rc={r.returncode} out={r.stdout.strip()} err={r.stderr.strip()}")
    if r.returncode == 0:
        print(f"  SUCCESS with {cred}!")
        break
