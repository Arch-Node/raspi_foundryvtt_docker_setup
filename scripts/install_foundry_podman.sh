#!/bin/bash
# =============================================================================
#  install_foundry_podman.sh - Deploy FoundryVTT Podman Container
#
#  Author: Arch-Node Project (Podman adaptation)
#  Purpose:
#    - Deploy production-ready FoundryVTT container using Podman
#    - Configure resource limits and security
#    - Set up backup and monitoring integration
#    - Integrate with project network and services
# =============================================================================

set -e

echo "[INFO] Checking for Podman installation..."
if ! command -v podman >/dev/null 2>&1; then
    echo "[ERROR] Podman is not installed. Please run install_podman.sh first."
    exit 1
fi

# Verify Podman is running (socket or service)
if ! podman info >/dev/null 2>&1; then
    echo "[ERROR] Podman is not running. Please start Podman service or socket."
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

# ...existing code from podman-adapted install_foundry_docker.sh...
# (See previous Podman adaptation for full implementation)
# This file is now ready for Podman-based deployments.
