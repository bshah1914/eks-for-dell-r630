@echo off
set GOVC_URL=https://192.168.50.163
set GOVC_USERNAME=root
set GOVC_PASSWORD=Admin@123$
set GOVC_INSECURE=true
set GOVC=C:\Users\dell\bin\govc.exe

echo === Checking VM guest identity ===
%GOVC% guest.run -vm k8s-master -l "ubuntu:ubuntu" /usr/bin/whoami
if %ERRORLEVEL% NEQ 0 (
    echo Trying default cloud image user...
    %GOVC% guest.run -vm k8s-master -l "root:root" /usr/bin/whoami
)
