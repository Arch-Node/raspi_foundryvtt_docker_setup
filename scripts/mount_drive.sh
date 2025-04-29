#!/bin/bash
# =============================================================================
#  mount_drive.sh - Mount External Backup Drive (Optional)
#
#  Author: Arch-Node Project
# =============================================================================

set -e

# Load environment variables
if [ -f ./env/drive_mount.env ]; then
  export $(grep -v '^#' ./env/drive_mount.env | xargs)
else
  echo "[ERROR] Missing env/drive_mount.env. Cannot proceed with mounting."
  exit 1
fi

if [ "$MOUNT_DRIVE_ENABLED" != "true" ]; then
  echo "[INFO] External drive mounting is disabled. Skipping mount."
  exit 0
fi

echo "[INFO] Mounting external backup drive to $MOUNT_POINT..."

# Ensure mount point exists
sudo mkdir -p "$MOUNT_POINT"

# Backup fstab first
sudo cp /etc/fstab /etc/fstab.backup

# Add UUID to fstab if missing
if ! grep -q "$DEVICE_UUID" /etc/fstab; then
  echo "UUID=$DEVICE_UUID $MOUNT_POINT ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
fi

sudo mount -a

echo "[INFO] External drive mounted successfully."
