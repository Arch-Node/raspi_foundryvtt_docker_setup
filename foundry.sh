#!/bin/bash
# =============================================================================
#  foundry.sh - Interactive Management Menu for FoundryVTT Docker Container
#
#  Author: Arch-Node Project
#  Purpose:
#    - Start/Stop/Restart FoundryVTT server
#    - View server status
#    - Trigger manual backups
#    - Trigger manual health checks
#
#  Usage:
#    $ chmod +x foundry.sh
#    $ ./foundry.sh
#
# =============================================================================

# Load container name dynamically
if [ -f ./env/foundry.env ]; then
  export $(grep -v '^#' ./env/foundry.env | xargs)
else
  echo "[ERROR] Missing env/foundry.env. Cannot proceed."
  exit 1
fi

IMAGE_TAG="${FOUNDRY_IMAGE##*:}"
CONTAINER_NAME="foundryvtt-${IMAGE_TAG}"

trap "echo Exiting...; exit 0" SIGINT

while true; do
  clear
  echo "======================================"
  echo " FoundryVTT Management Menu"
  echo " Container: $CONTAINER_NAME"
  echo "======================================"
  echo "1) Start FoundryVTT"
  echo "2) Stop FoundryVTT"
  echo "3) Restart FoundryVTT"
  echo "4) View Status"
  echo "5) Trigger Backup"
  echo "6) Run Health Check"
  echo "7) Exit"
  echo "======================================"
  read -rp "Choose an option: " choice
  case $choice in
    1) docker start "$CONTAINER_NAME" ;;
    2) docker stop "$CONTAINER_NAME" ;;
    3) docker restart "$CONTAINER_NAME" ;;
    4) docker ps | grep "$CONTAINER_NAME" || echo "Container not running." ;;
    5) echo "[INFO] Triggering manual backup..."
       python3 python/backup_now.py ;;
    6) echo "[INFO] Running manual health check..."
       python3 python/health_check.py ;;
    7) echo "Goodbye!" ; exit 0 ;;
    *) echo "Invalid option! Please try again." ;;
  esac
  echo "Press enter to continue..."
  read
done
