#!/bin/bash
set -e   # script stops if something fails
REPO_URL="https://github.com/daria-dot/tech613-tictactoe.git"

REPO_DIR="$HOME/tech613-tictactoe"
APP_DIR="$REPO_DIR/app"

sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y
# suppress prompts and auto select defaults

sudo apt install git -y
# clone repo at first and later pull
if [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" pull
else
    git clone "$REPO_URL" "$REPO_DIR"
fi


curl -fsSL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
sudo -E bash nodesource_setup.sh
sudo apt install nodejs -y

cd "$APP_DIR"
npm install
sudo npm install -g pm2
#ensure idempotency
pm2 delete tictactoe 2>/dev/null || true
pm2 start index.js --name tictactoe
pm2 save
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u "$USER" --hp "$HOME"


# Nginx reverse proxy (port 80 -> app on 3000)
sudo apt install nginx -y
sudo tee /etc/nginx/sites-available/default > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
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




