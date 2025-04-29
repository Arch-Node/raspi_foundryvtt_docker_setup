#!/bin/bash
# =============================================================================
#  install_docker.sh - Install Docker Engine for Raspberry Pi FoundryVTT Setup
#
#  Author: Arch-Node Project
#  Purpose:
#    - Install Docker using official convenience script
#    - Ensure user is added to docker group
#    - Prepare system for container deployments
#
#  Usage:
#    ./scripts/install_docker.sh
#
#  Notes:
#    - Designed for Debian-based Raspberry Pi OS systems
#    - Requires sudo/root access
# =============================================================================

set -e

echo "[INFO] Checking if Docker is already installed..."
if command -v docker >/dev/null 2>&1; then
    echo "[INFO] Docker is already installed. Skipping installation."
    exit 0
fi

echo "[INFO] Installing Docker..."

# Download the official Docker install script
curl -fsSL https://get.docker.com -o get-docker.sh

# Run the installer
sudo sh get-docker.sh

# Clean up installer script
rm -f get-docker.sh

# Add the current user to the docker group
sudo usermod -aG docker "$USER"

echo "[INFO] Docker installation complete."
echo "[INFO] You may need to log out and back in or reboot for group permissions to apply."
