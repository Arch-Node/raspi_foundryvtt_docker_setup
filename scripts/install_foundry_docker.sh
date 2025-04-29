#!/bin/bash
set -e

echo "[INFO] Checking for Docker installation..."
if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] Docker is not installed. Please run install_docker.sh first."
    exit 1
fi

# Load environment variables
if [ -f ./env/foundry.env ]; then
  export $(grep -v '^#' ./env/foundry.env | xargs)
else
  echo "[ERROR] Missing env/foundry.env. Please create it first."
  exit 1
fi

# Dynamically build container name from image tag
IMAGE_TAG="${FOUNDRY_IMAGE##*:}"
CONTAINER_NAME="foundryvtt-${IMAGE_TAG}"

echo "[INFO] Pulling FoundryVTT image: $FOUNDRY_IMAGE"
docker pull "$FOUNDRY_IMAGE"

# Create volume if missing
if ! docker volume inspect "$FOUNDRY_VOLUME" >/dev/null 2>&1; then
    echo "[INFO] Creating Docker volume $FOUNDRY_VOLUME..."
    docker volume create "$FOUNDRY_VOLUME"
fi

# Stop and remove old container if exists
if docker ps -a --format '{{.Names}}' | grep -Eq "^$CONTAINER_NAME\$"; then
    echo "[INFO] Stopping and removing existing container $CONTAINER_NAME..."
    docker stop "$CONTAINER_NAME" || true
    docker rm "$CONTAINER_NAME" || true
fi

echo "[INFO] Starting new FoundryVTT container..."
docker run -d \
  --name "$CONTAINER_NAME" \
  -p "$FOUNDRY_PORT_PUBLIC:$FOUNDRY_PORT_INTERNAL" \
  -v "$FOUNDRY_VOLUME":/data \
  -e FOUNDRY_USERNAME="$FOUNDRY_USERNAME" \
  -e FOUNDRY_PASSWORD="$FOUNDRY_PASSWORD" \
  --restart unless-stopped \
  "$FOUNDRY_IMAGE"

echo "[INFO] FoundryVTT container $CONTAINER_NAME is now running on port $FOUNDRY_PORT_PUBLIC."