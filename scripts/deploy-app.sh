#!/bin/bash
# Task 2: Deploy the tic-tac-toe app, connect it to MongoDB and seed the database.
#
# Manually (as ubuntu):  bash deploy-app.sh <DB-PRIVATE-IP>
# As user data:          paste the whole script and set DB_IP below (user data can't take arguments)
set -e   # stop if something fails

DB_IP="${1:-172.31.62.214}"          # DB instance private IP
MONGODB_URI="mongodb://${DB_IP}:27017/tictactoe"
REPO_URL="https://github.com/daria-dot/tech613-tictactoe.git"

# User data runs as root, so always install/run the app as ubuntu
if [ "$(id -u)" -eq 0 ]; then APP_USER="ubuntu"; else APP_USER="$(whoami)"; fi
APP_HOME="$(getent passwd "$APP_USER" | cut -d: -f6)"
REPO_DIR="$APP_HOME/tech613-tictactoe"
APP_DIR="$REPO_DIR/app"

# run a command as the app user (works whether the script runs as root or ubuntu)
as_app() {
    if [ "$(id -u)" -eq 0 ]; then sudo -u "$APP_USER" -H "$@"; else "$@"; fi
}

# no interactive prompts during installs/upgrades
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

sudo -E apt update
sudo -E apt upgrade -y
sudo -E apt install -y git curl nginx

# Node.js 20 + pm2
curl -fsSL https://deb.nodesource.com/setup_20.x -o /tmp/nodesource_setup.sh
sudo -E bash /tmp/nodesource_setup.sh
sudo -E apt install -y nodejs
sudo npm install -g pm2

# Clone the first time, pull after that
if [ -d "$REPO_DIR/.git" ]; then
    as_app git -C "$REPO_DIR" pull
else
    as_app git clone "$REPO_URL" "$REPO_DIR"
fi

# Env var: save it for future logins so manual commands (e.g. re-seeding) work too
BASHRC="$APP_HOME/.bashrc"
sed -i '/^export MONGODB_URI=/d' "$BASHRC"
echo "export MONGODB_URI=$MONGODB_URI" >> "$BASHRC"

# Wait for the database (useful when both instances are launched together)
for i in $(seq 1 30); do
    (echo > "/dev/tcp/$DB_IP/27017") 2>/dev/null && { echo "Database reachable"; break; }
    echo "Waiting for database at $DB_IP:27017 ..."
    sleep 5
done

# Install dependencies (postinstall also seeds Mongo directly because MONGODB_URI is set)
cd "$APP_DIR"
as_app env MONGODB_URI="$MONGODB_URI" npm install

# Start the app with the env var (pm2 save keeps it for restarts/reboots)
as_app pm2 delete tictactoe 2>/dev/null || true
as_app env MONGODB_URI="$MONGODB_URI" pm2 start index.js --name tictactoe --update-env
as_app pm2 save
sudo env PATH="$PATH:/usr/bin" pm2 startup systemd -u "$APP_USER" --hp "$APP_HOME"

# Seed through the running app, so it goes into whichever store the app is using
for i in $(seq 1 30); do
    curl -s -o /dev/null http://localhost:3000 && break
    sleep 1
done
as_app env MONGODB_URI="$MONGODB_URI" node seeds/seed.js

# Nginx reverse proxy (port 80 -> app on 3000)
sudo tee /etc/nginx/sites-available/default > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000; # reroutes traffic from port 80 to 3000 on this machine
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

# Show which mode the app is in (should be "Persistent with Mongo DB")
curl -s http://localhost:3000 | grep -o 'Mode: [^<]*' || true