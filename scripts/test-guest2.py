import subprocess, os

GOVC = r"C:\Users\dell\bin\govc.exe"
ENV = os.environ.copy()
ENV.update({
    "GOVC_URL": "https://192.168.50.163",
    "GOVC_USERNAME": "root",
    "GOVC_PASSWORD": "Admin@123$",
    "GOVC_INSECURE": "true",
})

# Test different command formats
tests = [
    [GOVC, "guest.run", "-vm", "k8s-master", "-l", "ubuntu:Admin@123$", "/usr/bin/id"],
    [GOVC, "guest.run", "-vm", "k8s-master", "-l", "ubuntu:Admin@123$", "/bin/ls", "/home"],
    [GOVC, "guest.run", "-vm", "k8s-master", "-l", "ubuntu:Admin@123$", "/bin/mkdir", "-p", "/home/ubuntu/.ssh"],
]

for cmd in tests:
    print(f"CMD: {' '.join(cmd[-3:])}")
    r = subprocess.run(cmd, env=ENV, capture_output=True, text=True, timeout=15)
    print(f"  rc={r.returncode} out={r.stdout.strip()[:100]} err={r.stderr.strip()[:100]}")
    print()
