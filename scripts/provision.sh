#!/bin/bash
# provision.sh - runs INSIDE the image chroot during build.
set -euo pipefail

source /tmp/config.sh

export DEBIAN_FRONTEND=noninteractive

echo ">> apt update"
apt-get update -o Acquire::Retries=3 || { echo "ERROR: apt-get update failed"; exit 1; }

echo ">> installing package set"
xargs -a /tmp/packages.list apt-get install -y --no-install-recommends

echo ">> configuring users"
# root: random password, emitted to the build artifacts
ROOT_PW="$(openssl rand -base64 18)"
echo "root:${ROOT_PW}" | chpasswd
echo "$ROOT_PW" > /tmp/ROOT_PASSWORD.txt

# ubuntu:ubuntu in sudo (standard cloud-image convention)
useradd -m -s /bin/bash ubuntu
echo "ubuntu:${UBUNTU_PASSWORD}" | chpasswd
usermod -aG sudo ubuntu

# passwordless sudo for the provisioning user (cloud-image convention)
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-ubuntu-cloud
chmod 440 /etc/sudoers.d/90-ubuntu-cloud

echo ">> enabling services"
systemctl enable ssh systemd-networkd systemd-resolved

echo ">> base identity"
echo "udm-ubuntu" > /etc/hostname
cat > /etc/hosts <<'EOF'
127.0.0.1 localhost udm-ubuntu
::1 localhost
EOF

echo ">> provisioning complete"
