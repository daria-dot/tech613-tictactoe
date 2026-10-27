#!/bin/bash
# Task 3: User data version of the MongoDB deployment.
# Paste into EC2 -> Launch instance -> Advanced details -> User data.
# User data runs once, as root, on the instance's first boot, so no sudo is needed.
# Output is logged to /var/log/cloud-init-output.log
set -e   # stop if something fails

MONGO_VERSION="8.0"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"   # jammy / noble
KEYRING="/usr/share/keyrings/mongodb-server-${MONGO_VERSION}.gpg"

# no interactive prompts during installs/upgrades
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

apt update
apt upgrade -y
apt install -y gnupg curl

# Add MongoDB's signing key and apt repository
curl -fsSL "https://www.mongodb.org/static/pgp/server-${MONGO_VERSION}.asc" \
  | gpg --dearmor --yes -o "$KEYRING"
echo "deb [ arch=amd64,arm64 signed-by=${KEYRING} ] https://repo.mongodb.org/apt/ubuntu ${CODENAME}/mongodb-org/${MONGO_VERSION} multiverse" \
  > "/etc/apt/sources.list.d/mongodb-org-${MONGO_VERSION}.list"

apt update
apt install -y mongodb-org

# Config change: listen on all interfaces instead of only 127.0.0.1
sed -i 's/^\(\s*bindIp:\).*/\1 0.0.0.0/' /etc/mongod.conf

# Kernel fix: MongoDB 8.x refuses to start on Linux kernel 6.19+ (SERVER-121912).
# This setting lets it run on those kernels; it does nothing on older kernels.
mkdir -p /etc/systemd/system/mongod.service.d
printf '[Service]\nEnvironment="GLIBC_TUNABLES=glibc.pthread.rseq=1"\n' \
  > /etc/systemd/system/mongod.service.d/kernel-fix.conf
systemctl daemon-reload

# Start now and on every boot
systemctl enable mongod
systemctl restart mongod

echo "MongoDB user data finished"