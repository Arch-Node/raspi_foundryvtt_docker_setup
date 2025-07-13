#!/bin/bash
# =============================================================================
#  install_foundry_docker.sh - Deploy FoundryVTT Docker Container
#
#  Author: Arch-Node Project
#  Purpose:
#    - Deploy production-ready FoundryVTT container
#    - Configure resource limits and security
#    - Set up backup and monitoring integration
#    - Integrate with project network and services
# =============================================================================

set -e

echo "[INFO] Checking for Docker installation..."
if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] Docker is not installed. Please run install_docker.sh first."
    exit 1
fi

# Verify Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "[ERROR] Docker is not running. Please start Docker service."
    exit 1
fi

# Load environment variables
if [ -f ./env/foundry.env ]; then
    export $(grep -v '^#' ./env/foundry.env | xargs)
elif [ -f ../env/foundry.env ]; then
    export $(grep -v '^#' ../env/foundry.env | xargs)
else
    echo "[ERROR] Missing env/foundry.env. Please create it first."
    exit 1
fi

# Load backup configuration if available
if [ -f ./env/backup.env ]; then
    export $(grep -v '^#' ./env/backup.env | xargs)
elif [ -f ../env/backup.env ]; then
    export $(grep -v '^#' ../env/backup.env | xargs)
fi

# Set defaults for optional variables
FOUNDRY_USERNAME=${FOUNDRY_USERNAME:-""}
FOUNDRY_PASSWORD=${FOUNDRY_PASSWORD:-""}
FOUNDRY_ADMIN_KEY=${FOUNDRY_ADMIN_KEY:-""}
FOUNDRY_LICENSE_KEY=${FOUNDRY_LICENSE_KEY:-""}
FOUNDRY_WORLD=${FOUNDRY_WORLD:-""}

# Dynamically build container name from image tag
IMAGE_TAG="${FOUNDRY_IMAGE##*:}"
CONTAINER_NAME="foundryvtt-${IMAGE_TAG}"

echo "[INFO] =============================================="
echo "[INFO] FoundryVTT Container Deployment"
echo "[INFO] =============================================="
echo "[INFO] Image: $FOUNDRY_IMAGE"
echo "[INFO] Container: $CONTAINER_NAME"
echo "[INFO] Public Port: $FOUNDRY_PORT_PUBLIC"
echo "[INFO] Internal Port: $FOUNDRY_PORT_INTERNAL"
echo "[INFO] Volume: $FOUNDRY_VOLUME"
echo "[INFO] =============================================="

# Create backup directory if specified
if [ -n "$BACKUP_FOLDER" ]; then
    echo "[INFO] Creating backup directory: $BACKUP_FOLDER"
    sudo mkdir -p "$BACKUP_FOLDER"
    sudo chown $(id -u):$(id -g) "$BACKUP_FOLDER"
fi

# Ensure FoundryVTT network exists
if ! docker network ls | grep -q "foundryvtt-net"; then
    echo "[INFO] Creating FoundryVTT network..."
    docker network create foundryvtt-net --driver bridge
fi

echo "[INFO] Pulling FoundryVTT image: $FOUNDRY_IMAGE"
if ! docker pull "$FOUNDRY_IMAGE"; then
    echo "[ERROR] Failed to pull FoundryVTT image!"
    exit 1
fi

# Create volume if missing
if ! docker volume inspect "$FOUNDRY_VOLUME" >/dev/null 2>&1; then
    echo "[INFO] Creating Docker volume $FOUNDRY_VOLUME..."
    docker volume create "$FOUNDRY_VOLUME"
else
    echo "[INFO] Using existing volume $FOUNDRY_VOLUME"
fi

# Create backup volume if backup is configured
if [ -n "$BACKUP_FOLDER" ]; then
    BACKUP_VOLUME="foundry_backups"
    if ! docker volume inspect "$BACKUP_VOLUME" >/dev/null 2>&1; then
        echo "[INFO] Creating backup volume $BACKUP_VOLUME..."
        docker volume create --driver local \
            --opt type=none \
            --opt o=bind \
            --opt device="$BACKUP_FOLDER" \
            "$BACKUP_VOLUME"
    fi
fi

# Stop and remove old container if exists
if docker ps -a --format '{{.Names}}' | grep -Eq "^$CONTAINER_NAME\$"; then
    echo "[INFO] Stopping and removing existing container $CONTAINER_NAME..."
    docker stop "$CONTAINER_NAME" || true
    docker rm "$CONTAINER_NAME" || true
fi

# Build Docker run command with comprehensive configuration
echo "[INFO] Starting new FoundryVTT container with production configuration..."

# Base container arguments
DOCKER_ARGS=(
    "run" "-d"
    "--name" "$CONTAINER_NAME"
    "--network" "foundryvtt-net"
    "-p" "$FOUNDRY_PORT_PUBLIC:$FOUNDRY_PORT_INTERNAL"
    "--restart" "unless-stopped"
)

# Resource limits for Raspberry Pi
DOCKER_ARGS+=(
    "--memory" "2g"
    "--memory-swap" "3g"
    "--cpus" "2.0"
    "--oom-kill-disable"
)

# Health check
DOCKER_ARGS+=(
    "--health-cmd" "curl -f http://localhost:$FOUNDRY_PORT_INTERNAL || exit 1"
    "--health-interval" "30s"
    "--health-timeout" "10s"
    "--health-retries" "3"
    "--health-start-period" "60s"
)

# Volume mounts
DOCKER_ARGS+=(
    "-v" "$FOUNDRY_VOLUME:/data"
)

# Add backup volume if configured
if [ -n "$BACKUP_FOLDER" ]; then
    DOCKER_ARGS+=(
        "-v" "$BACKUP_VOLUME:/backups"
    )
fi

# Environment variables
DOCKER_ARGS+=(
    "-e" "FOUNDRY_HOSTNAME=0.0.0.0"
    "-e" "FOUNDRY_PORT=$FOUNDRY_PORT_INTERNAL"
    "-e" "FOUNDRY_LOCAL_HOSTNAME=$(hostname -I | awk '{print $1}')"
)

# Add optional credentials if provided
if [ -n "$FOUNDRY_USERNAME" ] && [ -n "$FOUNDRY_PASSWORD" ]; then
    DOCKER_ARGS+=(
        "-e" "FOUNDRY_USERNAME=$FOUNDRY_USERNAME"
        "-e" "FOUNDRY_PASSWORD=$FOUNDRY_PASSWORD"
    )
fi

if [ -n "$FOUNDRY_ADMIN_KEY" ]; then
    DOCKER_ARGS+=(
        "-e" "FOUNDRY_ADMIN_KEY=$FOUNDRY_ADMIN_KEY"
    )
fi

if [ -n "$FOUNDRY_LICENSE_KEY" ]; then
    DOCKER_ARGS+=(
        "-e" "FOUNDRY_LICENSE_KEY=$FOUNDRY_LICENSE_KEY"
    )
fi

if [ -n "$FOUNDRY_WORLD" ]; then
    DOCKER_ARGS+=(
        "-e" "FOUNDRY_WORLD=$FOUNDRY_WORLD"
    )
fi

# Security options
DOCKER_ARGS+=(
    "--security-opt" "no-new-privileges:true"
    "--read-only=false"
    "--tmpfs" "/tmp:rw,noexec,nosuid,size=100m"
)

# Logging configuration
DOCKER_ARGS+=(
    "--log-driver" "json-file"
    "--log-opt" "max-size=100m"
    "--log-opt" "max-file=3"
)

# Add image as final argument
DOCKER_ARGS+=("$FOUNDRY_IMAGE")

# Run the container
if docker "${DOCKER_ARGS[@]}"; then
    echo "[INFO] FoundryVTT container started successfully!"
else
    echo "[ERROR] Failed to start FoundryVTT container!"
    exit 1
fi

# Wait for container to be healthy
echo "[INFO] Waiting for FoundryVTT to be ready..."
sleep 10

# Check container status
CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
if [ "$CONTAINER_STATUS" = "running" ]; then
    echo "[INFO] Container is running successfully!"
else
    echo "[ERROR] Container failed to start. Status: $CONTAINER_STATUS"
    echo "[ERROR] Container logs:"
    docker logs "$CONTAINER_NAME" --tail 20
    exit 1
fi

# Wait for health check
echo "[INFO] Waiting for health check to pass..."
for i in {1..12}; do
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "none")
    case $HEALTH_STATUS in
        "healthy")
            echo "[INFO] Health check passed!"
            break
            ;;
        "unhealthy")
            echo "[ERROR] Health check failed!"
            docker logs "$CONTAINER_NAME" --tail 20
            exit 1
            ;;
        "starting"|"none")
            echo "[INFO] Health check in progress... ($i/12)"
            sleep 10
            ;;
    esac
    
    if [ $i -eq 12 ]; then
        echo "[WARNING] Health check timeout, but container is running."
    fi
done

# Create container management script
echo "[INFO] Creating container management script..."
cat > foundry-container.sh << 'EOF'
#!/bin/bash
# FoundryVTT Container Management Script

CONTAINER_NAME="foundryvtt-release"  # Will be updated dynamically

case "$1" in
    "start")
        echo "Starting FoundryVTT container..."
        docker start "$CONTAINER_NAME"
        ;;
    "stop")
        echo "Stopping FoundryVTT container..."
        docker stop "$CONTAINER_NAME"
        ;;
    "restart")
        echo "Restarting FoundryVTT container..."
        docker restart "$CONTAINER_NAME"
        ;;
    "status")
        echo "=== Container Status ==="
        docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "=== Health Status ==="
        docker inspect --format='Health: {{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "No health check configured"
        echo ""
        echo "=== Resource Usage ==="
        docker stats "$CONTAINER_NAME" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
        ;;
    "logs")
        docker logs "$CONTAINER_NAME" --tail 50 -f
        ;;
    "exec")
        docker exec -it "$CONTAINER_NAME" /bin/bash
        ;;
    "backup")
        echo "Creating backup of FoundryVTT data..."
        docker exec "$CONTAINER_NAME" tar czf /backups/foundry-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .
        ;;
    *)
        echo "FoundryVTT Container Management"
        echo "Usage: $0 {start|stop|restart|status|logs|exec|backup}"
        ;;
esac
EOF

# Update container name in script
sed -i "s/foundryvtt-release/$CONTAINER_NAME/g" foundry-container.sh
chmod +x foundry-container.sh

# Create systemd service for container
echo "[INFO] Creating systemd service for FoundryVTT container..."
sudo tee /etc/systemd/system/foundryvtt-container.service > /dev/null <<EOF
[Unit]
Description=FoundryVTT Container
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker start $CONTAINER_NAME
ExecStop=/usr/bin/docker stop $CONTAINER_NAME
TimeoutStartSec=60
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable foundryvtt-container.service

# Final status and connection info
echo "[INFO] =============================================="
echo "[INFO] 🎉 FoundryVTT Container Deployment Complete! 🎉"
echo "[INFO] =============================================="
echo "[INFO]"
echo "[INFO] Container Details:"
echo "[INFO] - Name: $CONTAINER_NAME"
echo "[INFO] - Status: $(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME")"
echo "[INFO] - Health: $(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo 'No health check')"
echo "[INFO]"
echo "[INFO] Access Information:"
echo "[INFO] - Local URL: http://$(hostname -I | awk '{print $1}'):$FOUNDRY_PORT_PUBLIC"
echo "[INFO] - Local URL: http://localhost:$FOUNDRY_PORT_PUBLIC"
echo "[INFO]"
echo "[INFO] Management Commands:"
echo "[INFO] - ./foundry-container.sh status"
echo "[INFO] - ./foundry-container.sh logs"
echo "[INFO] - ./foundry-container.sh restart"
echo "[INFO] - ./foundry-container.sh backup"
echo "[INFO]"
echo "[INFO] System Integration:"
echo "[INFO] - Systemd service: foundryvtt-container.service"
echo "[INFO] - Docker network: foundryvtt-net"
echo "[INFO] - Data volume: $FOUNDRY_VOLUME"
if [ -n "$BACKUP_FOLDER" ]; then
echo "[INFO] - Backup volume: $BACKUP_VOLUME -> $BACKUP_FOLDER"
fi
echo "[INFO]"
echo "[INFO] FoundryVTT is now running and ready for use!"
echo "[INFO] =============================================="