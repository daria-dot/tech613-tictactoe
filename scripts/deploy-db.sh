#!/bin/bash
# Task 1: Deploy MongoDB on Ubuntu (22.04 or 24.04) and allow connections from the app instance.
# Run on the DB instance as the ubuntu user:  bash deploy-db.sh
set -e   # stop if something fails

MONGO_VERSION="8.0"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"   # jammy / noble
KEYRING="/usr/share/keyrings/mongodb-server-${MONGO_VERSION}.gpg"

# no interactive prompts during installs/upgrades
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

sudo -E apt update
sudo -E apt upgrade -y
sudo -E apt install -y gnupg curl

# Add MongoDB's signing key and apt repository (--yes overwrites on reruns)
curl -fsSL "https://www.mongodb.org/static/pgp/server-${MONGO_VERSION}.asc" \
  | sudo gpg --dearmor --yes -o "$KEYRING"
echo "deb [ arch=amd64,arm64 signed-by=${KEYRING} ] https://repo.mongodb.org/apt/ubuntu ${CODENAME}/mongodb-org/${MONGO_VERSION} multiverse" \
  | sudo tee "/etc/apt/sources.list.d/mongodb-org-${MONGO_VERSION}.list" > /dev/null

sudo -E apt update
sudo -E apt install -y mongodb-org

# Config change: listen on all interfaces instead of only 127.0.0.1

sudo sed -i 's/^\(\s*bindIp:\).*/\1 0.0.0.0/' /etc/mongod.conf

# Start now and on every boot
sudo systemctl enable mongod
sudo systemctl restart mongod

# Wait for MongoDB to be listening, then show the result
for i in $(seq 1 30); do
    ss -tln | grep -q ':27017' && break
    sleep 1
done
grep bindIp /etc/mongod.conf
ss -tln | grep ':27017'
echo "MongoDB is running and listening on 0.0.0.0:27017"