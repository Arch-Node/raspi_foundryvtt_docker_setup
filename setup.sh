#!/bin/bash
# =============================================================================
#  setup.sh - Automated Setup for Raspberry Pi FoundryVTT Docker System
#
#  Author: Arch-Node Project
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Initialize Logs
# -----------------------------------------------------------------------------
mkdir -p logs
INSTALL_LOG="logs/install.log"
echo "$(date +"[%Y-%m-%d %H:%M:%S]") Starting setup" > "$INSTALL_LOG"

timestamp() {
  date +"[%Y-%m-%d %H:%M:%S]"
}

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
ensure_directories() {
  local dirs=("env" "logs" "plots" "backups" "python" "scripts" "systemd")

  for dir in "${dirs[@]}"; do
    if [ ! -d "$dir" ]; then
      echo "$(timestamp) Creating missing folder: $dir" | tee -a "$INSTALL_LOG"
      mkdir -p "$dir"
    else
      echo "$(timestamp) Found folder: $dir" | tee -a "$INSTALL_LOG"
    fi
  done
}

check_and_install() {
    local package=$1
    if ! dpkg -s "$package" >/dev/null 2>&1; then
        echo "$(timestamp) Installing package: $package..." | tee -a "$INSTALL_LOG"
        sudo apt-get install -y "$package" | tee -a "$INSTALL_LOG"
    else
        echo "$(timestamp) Package $package already installed." | tee -a "$INSTALL_LOG"
    fi
}

check_and_install_python() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo "$(timestamp) Installing Python3..." | tee -a "$INSTALL_LOG"
        sudo apt-get install -y python3 | tee -a "$INSTALL_LOG"
    fi
}

check_and_install_pip() {
    if ! command -v pip3 >/dev/null 2>&1; then
        echo "$(timestamp) Installing python3-pip..." | tee -a "$INSTALL_LOG"
        sudo apt-get install -y python3-pip | tee -a "$INSTALL_LOG"
    fi
}

check_and_install_python_package() {
    local package=$1
    if ! python3 -c "import $package" >/dev/null 2>&1; then
        echo "$(timestamp) Installing Python package: $package..." | tee -a "$INSTALL_LOG"
        pip3 install "$package" | tee -a "$INSTALL_LOG"
    fi
}

# -----------------------------------------------------------------------------
# Prompt for Environment Variables
# -----------------------------------------------------------------------------
prompt_for_envs() {
  echo "$(timestamp) Checking environment configuration..." | tee -a "$INSTALL_LOG"
  mkdir -p env

  # Drive Mount
  if [ ! -f env/drive_mount.env ]; then
    echo "Creating drive_mount.env:"
    read -p "Do you want to mount an external drive for backups? (y/n) [y]: " mount_drive_choice
    mount_drive_choice=${mount_drive_choice:-y}

    if [[ "$mount_drive_choice" =~ ^[Yy]$ ]]; then
      read -p "Enter backup mount point (default /backups): " mount_point
      mount_point=${mount_point:-/backups}
      read -p "Enter backup drive UUID: " uuid
      echo "MOUNT_DRIVE_ENABLED=true" > env/drive_mount.env
      echo "MOUNT_POINT=$mount_point" >> env/drive_mount.env
      echo "DEVICE_UUID=$uuid" >> env/drive_mount.env
    else
      echo "MOUNT_DRIVE_ENABLED=false" > env/drive_mount.env
      read -p "Do you want to use an existing folder for backups? (y/n) [y]: " existing_folder_choice
      existing_folder_choice=${existing_folder_choice:-y}

      if [[ "$existing_folder_choice" =~ ^[Yy]$ ]]; then
        read -p "Enter the existing backup folder path (e.g., /home/pi/backups): " mount_point
        echo "MOUNT_POINT=$mount_point" >> env/drive_mount.env
      else
        read -p "Enter the path to create for backups (e.g., /home/pi/backups): " mount_point
        sudo mkdir -p "$mount_point"
        echo "MOUNT_POINT=$mount_point" >> env/drive_mount.env
      fi
    fi
  fi

  # Backup Settings
  if [ ! -f env/backup.env ]; then
    echo "Creating backup.env:"
    read -p "Enter backup retention days (default 14): " retention_days
    retention_days=${retention_days:-14}
    echo "BACKUP_FOLDER=$mount_point" > env/backup.env
    echo "BACKUP_RETENTION_DAYS=$retention_days" >> env/backup.env
  fi

  # Signal CLI
  if [ ! -f env/signal.env ]; then
    echo "Creating signal.env:"
    read -p "Enter your Signal CLI registered number (e.g., +15551234567): " signal_user
    read -p "Enter your Signal Group ID: " group_id
    read -p "Enter authorized sender numbers (comma-separated): " authorized_senders
    echo "SIGNAL_CLI_USER=$signal_user" > env/signal.env
    echo "SIGNAL_GROUP_ID=$group_id" >> env/signal.env
    echo "AUTHORIZED_SENDERS=$authorized_senders" >> env/signal.env
  fi

  # DuckDNS
  if [ ! -f env/duckdns.env ]; then
    echo "Creating duckdns.env:"
    read -p "Enter your DuckDNS subdomain: " duck_domain
    read -p "Enter your DuckDNS token: " duck_token
    echo "DUCKDNS_DOMAIN=$duck_domain" > env/duckdns.env
    echo "DUCKDNS_TOKEN=$duck_token" >> env/duckdns.env
  fi

  # FoundryVTT Docker Settings
  if [ ! -f env/foundry.env ]; then
    echo "Creating foundry.env:"
    read -p "Enter external port to expose (default 29000): " public_port
    public_port=${public_port:-29000}
    read -p "Enter internal Foundry app port (default 30000): " internal_port
    internal_port=${internal_port:-30000}
    read -p "Enter Docker image to pull (default felddy/foundryvtt:release): " docker_image
    docker_image=${docker_image:-felddy/foundryvtt:release}
    read -p "Enter Docker volume name (default foundry_data): " volume_name
    volume_name=${volume_name:-foundry_data}
    read -p "Enter optional Foundry username (leave blank if not using licensed login): " foundry_username
    read -p "Enter optional Foundry password (leave blank if not using licensed login): " foundry_password

    echo "FOUNDRY_PORT_PUBLIC=$public_port" > env/foundry.env
    echo "FOUNDRY_PORT_INTERNAL=$internal_port" >> env/foundry.env
    echo "FOUNDRY_IMAGE=$docker_image" >> env/foundry.env
    echo "FOUNDRY_VOLUME=$volume_name" >> env/foundry.env
    echo "FOUNDRY_USERNAME=$foundry_username" >> env/foundry.env
    echo "FOUNDRY_PASSWORD=$foundry_password" >> env/foundry.env
  fi
}

# -----------------------------------------------------------------------------
# Start Setup Flow
# -----------------------------------------------------------------------------
echo "$(timestamp) Ensuring project folders..." | tee -a "$INSTALL_LOG"
ensure_directories

echo "$(timestamp) Checking system dependencies..." | tee -a "$INSTALL_LOG"
sudo apt-get update | tee -a "$INSTALL_LOG"

check_and_install "curl"
check_and_install "unzip"
check_and_install "openjdk-11-jre"
check_and_install "nginx"
check_and_install "docker.io"

check_and_install_python
check_and_install_pip

check_and_install_python_package "requests"
check_and_install_python_package "dotenv"

prompt_for_envs

# Source envs
echo "$(timestamp) Loading environment configurations..." | tee -a "$INSTALL_LOG"
source ./env/drive_mount.env
source ./env/backup.env
source ./env/signal.env
source ./env/duckdns.env
source ./env/foundry.env

# Install Python requirements
echo "$(timestamp) Installing Python requirements..." | tee -a "$INSTALL_LOG"
pip3 install -r python/requirements.txt | tee -a "$INSTALL_LOG"

# Make scripts executable
echo "$(timestamp) Setting script permissions..." | tee -a "$INSTALL_LOG"
chmod +x scripts/*.sh
chmod +x foundry.sh
chmod +x python/*.py

echo "$(timestamp) Running installation scripts..." | tee -a "$INSTALL_LOG"

# Install Docker with error handling
if ! ./scripts/install_docker.sh; then
    echo "$(timestamp) ERROR: Docker installation failed!" | tee -a "$INSTALL_LOG"
    exit 1
fi

# Install Nginx with error handling
if ! ./scripts/install_nginx.sh; then
    echo "$(timestamp) ERROR: Nginx installation failed!" | tee -a "$INSTALL_LOG"
    exit 1
fi

# Setup DuckDNS
if ! ./scripts/setup_duckdns.sh; then
    echo "$(timestamp) ERROR: DuckDNS setup failed!" | tee -a "$INSTALL_LOG"
    exit 1
fi

# Mount drive if enabled
if [[ "$MOUNT_DRIVE_ENABLED" == "true" ]]; then
    if ! ./scripts/mount_drive.sh; then
        echo "$(timestamp) ERROR: Drive mounting failed!" | tee -a "$INSTALL_LOG"
        exit 1
    fi
fi

# Install Signal CLI
if ! command -v signal-cli >/dev/null 2>&1; then
    echo "$(timestamp) Installing Signal CLI..." | tee -a "$INSTALL_LOG"
    if ! ./scripts/install_signal_cli.sh; then
        echo "$(timestamp) ERROR: Signal CLI installation failed!" | tee -a "$INSTALL_LOG"
        exit 1
    fi
fi

# Deploy Foundry container
echo "$(timestamp) Deploying Foundry container..." | tee -a "$INSTALL_LOG"
if ! ./scripts/install_foundry_docker.sh; then
    echo "$(timestamp) ERROR: Foundry container deployment failed!" | tee -a "$INSTALL_LOG"
    exit 1
fi

# Install and enable systemd services
echo "$(timestamp) Installing systemd services..." | tee -a "$INSTALL_LOG"
sudo cp systemd/*.service /etc/systemd/system/
sudo cp systemd/*.timer /etc/systemd/system/

# Reload systemd and enable services
sudo systemctl daemon-reload

echo "$(timestamp) Enabling systemd timers..." | tee -a "$INSTALL_LOG"
sudo systemctl enable check_and_update_foundry.timer
sudo systemctl enable rotate_backups.timer
sudo systemctl enable weekly_health_report.timer
sudo systemctl enable weekly_reboot.timer

echo "$(timestamp) Starting systemd timers..." | tee -a "$INSTALL_LOG"
sudo systemctl start check_and_update_foundry.timer
sudo systemctl start rotate_backups.timer
sudo systemctl start weekly_health_report.timer
sudo systemctl start weekly_reboot.timer

# Final validation
echo "$(timestamp) Running final validation..." | tee -a "$INSTALL_LOG"

# Check if Docker is running
if ! docker ps >/dev/null 2>&1; then
    echo "$(timestamp) ERROR: Docker is not running properly!" | tee -a "$INSTALL_LOG"
    exit 1
fi

# Check if Foundry container is running
CONTAINER_NAME="foundryvtt-${FOUNDRY_IMAGE##*:}"
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "$(timestamp) ERROR: Foundry container is not running!" | tee -a "$INSTALL_LOG"
    exit 1
fi

# Display success message and next steps
echo "$(timestamp) ========================================" | tee -a "$INSTALL_LOG"
echo "$(timestamp) 🎉 SETUP COMPLETE! 🎉" | tee -a "$INSTALL_LOG"
echo "$(timestamp) ========================================" | tee -a "$INSTALL_LOG"
echo "$(timestamp)" | tee -a "$INSTALL_LOG"
echo "$(timestamp) FoundryVTT is now running on port $FOUNDRY_PORT_PUBLIC" | tee -a "$INSTALL_LOG"
echo "$(timestamp) Container name: $CONTAINER_NAME" | tee -a "$INSTALL_LOG"
echo "$(timestamp)" | tee -a "$INSTALL_LOG"
echo "$(timestamp) Next steps:" | tee -a "$INSTALL_LOG"
echo "$(timestamp) 1. Access FoundryVTT at: http://$(hostname -I | awk '{print $1}'):$FOUNDRY_PORT_PUBLIC" | tee -a "$INSTALL_LOG"
echo "$(timestamp) 2. Use './foundry.sh' for container management" | tee -a "$INSTALL_LOG"
echo "$(timestamp) 3. Check systemd timer status: sudo systemctl list-timers" | tee -a "$INSTALL_LOG"
echo "$(timestamp) 4. Monitor logs in the 'logs/' directory" | tee -a "$INSTALL_LOG"
echo "$(timestamp)" | tee -a "$INSTALL_LOG"
echo "$(timestamp) All systemd services have been enabled and started." | tee -a "$INSTALL_LOG"
echo "$(timestamp) Setup complete!" | tee -a "$INSTALL_LOG"
