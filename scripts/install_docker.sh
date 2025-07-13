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

# Update package index
echo "[INFO] Updating package index..."
sudo apt-get update

# Install prerequisites
echo "[INFO] Installing prerequisites..."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Download the official Docker install script
echo "[INFO] Downloading Docker installation script..."
curl -fsSL https://get.docker.com -o get-docker.sh

# Run the installer
echo "[INFO] Running Docker installer..."
sudo sh get-docker.sh

# Clean up installer script
rm -f get-docker.sh

# Add the current user to the docker group
echo "[INFO] Adding user $USER to docker group..."
sudo usermod -aG docker "$USER"

# Enable and start Docker service
echo "[INFO] Enabling and starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

# Configure Docker daemon for Raspberry Pi optimization
echo "[INFO] Configuring Docker daemon settings..."
sudo mkdir -p /etc/docker

# Create Docker daemon configuration optimized for Raspberry Pi
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true,
  "userland-proxy": false,
  "experimental": false,
  "metrics-addr": "127.0.0.1:9323",
  "default-ulimits": {
    "nofile": {
      "hard": 64000,
      "soft": 64000
    }
  }
}
EOF

# Restart Docker to apply configuration
echo "[INFO] Restarting Docker to apply configuration..."
sudo systemctl restart docker

# Wait for Docker to be ready
echo "[INFO] Waiting for Docker to be ready..."
sleep 5

# Verify Docker installation
echo "[INFO] Verifying Docker installation..."
if sudo docker --version; then
    echo "[INFO] Docker version check passed."
else
    echo "[ERROR] Docker installation verification failed!"
    exit 1
fi

# Test Docker functionality
echo "[INFO] Testing Docker functionality..."
if sudo docker run --rm hello-world >/dev/null 2>&1; then
    echo "[INFO] Docker functionality test passed."
else
    echo "[ERROR] Docker functionality test failed!"
    exit 1
fi

# Install Docker Compose
echo "[INFO] Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify Docker Compose installation
if docker-compose --version >/dev/null 2>&1; then
    echo "[INFO] Docker Compose installed successfully: $(docker-compose --version)"
else
    echo "[WARNING] Docker Compose installation may have failed, but Docker is working."
fi

# Configure log rotation for Docker containers
echo "[INFO] Setting up Docker log rotation..."
sudo tee /etc/logrotate.d/docker > /dev/null <<EOF
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=100M
    missingok
    delaycompress
    copytruncate
}
EOF

# Set up Docker system prune cron job for cleanup
echo "[INFO] Setting up automated Docker cleanup..."
sudo tee /etc/cron.weekly/docker-cleanup > /dev/null <<EOF
#!/bin/bash
# Weekly Docker cleanup to prevent disk space issues
/usr/bin/docker system prune -af --filter "until=168h" > /var/log/docker-cleanup.log 2>&1
EOF
sudo chmod +x /etc/cron.weekly/docker-cleanup

# Create Docker monitoring script
echo "[INFO] Creating Docker monitoring helper..."
sudo tee /usr/local/bin/docker-status > /dev/null <<EOF
#!/bin/bash
# Docker status and monitoring helper

case "\$1" in
    "status")
        echo "=== Docker Service Status ==="
        systemctl status docker --no-pager
        echo ""
        echo "=== Running Containers ==="
        docker ps
        echo ""
        echo "=== Docker System Info ==="
        docker system df
        ;;
    "logs")
        if [ -n "\$2" ]; then
            docker logs "\$2" --tail 50
        else
            echo "Usage: docker-status logs CONTAINER_NAME"
        fi
        ;;
    "cleanup")
        echo "Running Docker cleanup..."
        docker system prune -af --filter "until=24h"
        ;;
    "stats")
        docker stats --no-stream
        ;;
    *)
        echo "Docker Status Helper"
        echo "Usage: docker-status {status|logs CONTAINER|cleanup|stats}"
        ;;
esac
EOF
sudo chmod +x /usr/local/bin/docker-status

# Configure memory limits for better Raspberry Pi performance
echo "[INFO] Configuring memory management..."
if ! grep -q "cgroup_enable=memory" /boot/cmdline.txt; then
    sudo sed -i 's/$/ cgroup_enable=memory cgroup_memory=1/' /boot/cmdline.txt
    echo "[INFO] Added memory cgroup support to boot configuration."
    echo "[WARNING] A reboot will be required for memory cgroup changes to take effect."
fi

# Set up Docker network for FoundryVTT
echo "[INFO] Creating FoundryVTT Docker network..."
if ! docker network ls | grep -q "foundryvtt-net"; then
    docker network create foundryvtt-net --driver bridge
    echo "[INFO] Created foundryvtt-net network."
else
    echo "[INFO] foundryvtt-net network already exists."
fi

# Final verification and status
echo "[INFO] Final Docker verification..."
docker_version=$(docker --version)
docker_compose_version=$(docker-compose --version 2>/dev/null || echo "Docker Compose not available")

echo "[INFO] =============================================="
echo "[INFO] Docker installation and configuration complete!"
echo "[INFO] =============================================="
echo "[INFO] Docker Version: $docker_version"
echo "[INFO] $docker_compose_version"
echo "[INFO]"
echo "[INFO] Configuration applied:"
echo "[INFO] - Optimized daemon settings for Raspberry Pi"
echo "[INFO] - Log rotation configured"
echo "[INFO] - Weekly cleanup scheduled"
echo "[INFO] - Memory cgroup support enabled"
echo "[INFO] - FoundryVTT network created"
echo "[INFO]"
echo "[INFO] Helper commands available:"
echo "[INFO] - docker-status status    (overall status)"
echo "[INFO] - docker-status logs NAME (container logs)"
echo "[INFO] - docker-status cleanup   (manual cleanup)"
echo "[INFO] - docker-status stats     (resource usage)"
echo "[INFO]"
echo "[INFO] User $USER has been added to docker group."
echo "[INFO] You may need to log out and back in for group permissions to apply."
echo "[INFO] =============================================="
