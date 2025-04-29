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

echo "[INFO] Enabling and starting Nginx service..."
sudo systemctl enable nginx
sudo systemctl start nginx

echo "[INFO] Nginx installation and basic configuration complete."
