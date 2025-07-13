#!/bin/bash
# =============================================================================
#  install_podman.sh - Install Podman Engine for FoundryVTT Setup
#
#  Author: Arch-Node Project (Podman adaptation)
#  Purpose:
#    - Install Podman and podman-compose
#    - Ensure user is added to podman group (if available)
#    - Prepare system for container deployments
#
#  Usage:
#    ./scripts/install_podman.sh
#
#  Notes:
#    - Designed for Debian-based and general Linux systems
#    - Requires sudo/root access
# =============================================================================

set -e

# --- Check for Podman ---
echo "[INFO] Checking if Podman is already installed..."
if command -v podman >/dev/null 2>&1; then
    echo "[INFO] Podman is already installed. Skipping installation."
else
    echo "[INFO] Installing Podman..."
    if [ -f /etc/debian_version ]; then
        sudo apt-get update
        sudo apt-get install -y podman
    elif [ -f /etc/redhat-release ]; then
        sudo dnf install -y podman
    else
        echo "[ERROR] Unsupported OS. Please install Podman manually."
        exit 1
    fi
fi

# --- Check for podman-compose ---
echo "[INFO] Checking for podman-compose..."
if command -v podman-compose >/dev/null 2>&1; then
    echo "[INFO] podman-compose is already installed."
else
    echo "[INFO] Installing podman-compose..."
    sudo pip3 install podman-compose
fi

# --- Add user to podman group if available ---
if getent group podman >/dev/null 2>&1; then
    echo "[INFO] Adding user $USER to podman group..."
    sudo usermod -aG podman "$USER"
fi

# --- Enable and start Podman socket/service ---
echo "[INFO] Enabling and starting Podman socket/service..."
sudo systemctl enable --now podman.socket || sudo systemctl enable --now podman.service

# --- Configure log rotation for Podman containers ---
echo "[INFO] Setting up Podman log rotation..."
sudo tee /etc/logrotate.d/podman-containers > /dev/null <<EOF
/var/lib/containers/storage/overlay-containers/*/userdata/ctr.log {
    rotate 7
    daily
    compress
    size=100M
    missingok
    delaycompress
    copytruncate
}
EOF

# --- Set up Podman system prune cron job for cleanup ---
echo "[INFO] Setting up automated Podman cleanup..."
sudo tee /etc/cron.weekly/podman-cleanup > /dev/null <<EOF
#!/bin/bash
# Weekly Podman cleanup to prevent disk space issues
/usr/bin/podman system prune -af --filter "until=168h" > /var/log/podman-cleanup.log 2>&1
EOF
sudo chmod +x /etc/cron.weekly/podman-cleanup

# --- Create Podman monitoring script ---
echo "[INFO] Creating Podman monitoring helper..."
sudo tee /usr/local/bin/podman-status > /dev/null <<EOF
#!/bin/bash
# Podman status and monitoring helper

case "$1" in
    "status")
        echo "=== Podman Service Status ==="
        systemctl status podman.socket --no-pager || systemctl status podman.service --no-pager
        echo ""
        echo "=== Running Containers ==="
        podman ps
        echo ""
        echo "=== Podman System Info ==="
        podman system df
        ;;
    "logs")
        if [ -n "$2" ]; then
            podman logs "$2" --tail 50
        else
            echo "Usage: podman-status logs CONTAINER_NAME"
        fi
        ;;
    "cleanup")
        echo "Running Podman cleanup..."
        podman system prune -af --filter "until=24h"
        ;;
    "stats")
        podman stats --no-stream
        ;;
    *)
        echo "Podman Status Helper"
        echo "Usage: podman-status {status|logs CONTAINER|cleanup|stats}"
        ;;
esac
EOF
sudo chmod +x /usr/local/bin/podman-status

# --- Create Podman network for FoundryVTT ---
echo "[INFO] Creating FoundryVTT Podman network..."
if ! podman network ls | grep -q "foundryvtt-net"; then
    podman network create foundryvtt-net
    echo "[INFO] Created foundryvtt-net network."
else
    echo "[INFO] foundryvtt-net network already exists."
fi

# --- Final verification and status ---
podman_version=$(podman --version)
podman_compose_version=$(podman-compose --version 2>/dev/null || echo "podman-compose not available")

echo "[INFO] =============================================="
echo "[INFO] Podman installation and configuration complete!"
echo "[INFO] =============================================="
echo "[INFO] Podman Version: $podman_version"
echo "[INFO] $podman_compose_version"
echo "[INFO]"
echo "[INFO] Configuration applied:"
echo "[INFO] - Log rotation configured"
echo "[INFO] - Weekly cleanup scheduled"
echo "[INFO] - FoundryVTT network created"
echo "[INFO]"
echo "[INFO] Helper commands available:"
echo "[INFO] - podman-status status    (overall status)"
echo "[INFO] - podman-status logs NAME (container logs)"
echo "[INFO] - podman-status cleanup   (manual cleanup)"
echo "[INFO] - podman-status stats     (resource usage)"
echo "[INFO]"
echo "[INFO] User $USER has been added to podman group (if available)."
echo "[INFO] You may need to log out and back in for group permissions to apply."
echo "[INFO] =============================================="
