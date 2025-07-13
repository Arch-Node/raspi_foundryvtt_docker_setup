#!/bin/bash
# =============================================================================
#  install_nginx.sh - Install and Configure Nginx for Raspberry Pi FoundryVTT Setup
#
#  Author: Arch-Node Project
#  Purpose:
#    - Install Nginx web server
#    - Enable and start Nginx service
#    - Prepare for optional future reverse proxy usage
#
#  Usage:
#    ./scripts/install_nginx.sh
#
#  Notes:
#    - Designed for Debian-based Raspberry Pi OS systems
#    - Requires sudo/root access
# =============================================================================

set -e

echo "[INFO] Checking if Nginx is already installed..."
if command -v nginx >/dev/null 2>&1; then
    echo "[INFO] Nginx is already installed. Skipping installation."
    exit 0
fi

echo "[INFO] Installing Nginx..."
sudo apt-get install -y nginx

# Load environment variables for configuration
if [ -f ../env/foundry.env ]; then
    export $(grep -v '^#' ../env/foundry.env | xargs)
elif [ -f ./env/foundry.env ]; then
    export $(grep -v '^#' ./env/foundry.env | xargs)
else
    echo "[ERROR] Cannot find foundry.env file. Nginx configuration may be incomplete."
    FOUNDRY_PORT_PUBLIC=${FOUNDRY_PORT_PUBLIC:-29000}
fi

echo "[INFO] Creating Nginx configuration for FoundryVTT..."

# Create FoundryVTT site configuration
sudo tee /etc/nginx/sites-available/foundryvtt > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Increase client max body size for file uploads
    client_max_body_size 300M;

    # Proxy settings for FoundryVTT
    location / {
        proxy_pass http://localhost:${FOUNDRY_PORT_PUBLIC};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support for FoundryVTT
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Optional: Serve static health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Security: Block access to sensitive files
    location ~ /\.ht {
        deny all;
    }
    
    location ~ /\.git {
        deny all;
    }
}
EOF

echo "[INFO] Enabling FoundryVTT site..."
sudo ln -sf /etc/nginx/sites-available/foundryvtt /etc/nginx/sites-enabled/

# Disable default site if it exists
if [ -f /etc/nginx/sites-enabled/default ]; then
    echo "[INFO] Disabling default Nginx site..."
    sudo rm -f /etc/nginx/sites-enabled/default
fi

echo "[INFO] Testing Nginx configuration..."
if sudo nginx -t; then
    echo "[INFO] Nginx configuration test passed."
else
    echo "[ERROR] Nginx configuration test failed!"
    exit 1
fi

echo "[INFO] Enabling and starting Nginx service..."
sudo systemctl enable nginx
sudo systemctl reload nginx
sudo systemctl start nginx

# Verify Nginx is running
if sudo systemctl is-active --quiet nginx; then
    echo "[INFO] Nginx is running successfully."
else
    echo "[ERROR] Nginx failed to start!"
    exit 1
fi

echo "[INFO] Nginx installation and FoundryVTT reverse proxy configuration complete."
echo "[INFO] FoundryVTT will be accessible on port 80 (HTTP) once the container is running."
