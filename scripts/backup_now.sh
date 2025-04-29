#!/usr/bin/env python3
# =============================================================================
#  backup_now.py - Manual Backup Script for FoundryVTT Server
#
#  Author: Arch-Node Project
#  Purpose:
#    - Copy live FoundryVTT data to external/internal backup folder
#    - Preserve backups with timestamped folders
#    - Enforce backup retention (cleanup old backups)
# =============================================================================

import os
import shutil
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Load environment variables
load_dotenv(dotenv_path="./env/drive_mount.env")
load_dotenv(dotenv_path="./env/backup.env")
load_dotenv(dotenv_path="./env/foundry.env")

# Define paths
FOUNDATION_SOURCE = f"/var/lib/docker/volumes/{os.getenv('FOUNDRY_VOLUME')}/_data"
BACKUP_BASE = os.getenv("MOUNT_POINT")
RETENTION_DAYS = int(os.getenv("BACKUP_RETENTION_DAYS", 14))

# Create timestamped backup folder
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
backup_folder = os.path.join(BACKUP_BASE, "foundry_backups", timestamp)

print(f"[INFO] Starting FoundryVTT backup...")
print(f"[INFO] Source: {FOUNDATION_SOURCE}")
print(f"[INFO] Destination: {backup_folder}")

# Ensure destination base exists
os.makedirs(backup_folder, exist_ok=True)

# Copy the Foundry data
try:
    shutil.copytree(FOUNDATION_SOURCE, backup_folder, dirs_exist_ok=True)
    print(f"[INFO] Backup completed successfully.")
except Exception as e:
    print(f"[ERROR] Backup failed: {e}")
    exit(1)

# Cleanup old backups
print(f"[INFO] Cleaning up backups older than {RETENTION_DAYS} days...")
cutoff = datetime.now() - timedelta(days=RETENTION_DAYS)

backup_root = os.path.join(BACKUP_BASE, "foundry_backups")

if os.path.exists(backup_root):
    for folder in os.listdir(backup_root):
        folder_path = os.path.join(backup_root, folder)
        if os.path.isdir(folder_path):
            try:
                folder_time = datetime.strptime(folder, "%Y%m%d_%H%M%S")
                if folder_time < cutoff:
                    print(f"[INFO] Deleting old backup: {folder_path}")
                    shutil.rmtree(folder_path)
            except ValueError:
                print(f"[WARNING] Skipping unknown folder format: {folder_path}")
else:
    print(f"[WARNING] Backup root {backup_root} does not exist. Nothing to clean.")

print("[INFO] Backup process completed successfully.")
