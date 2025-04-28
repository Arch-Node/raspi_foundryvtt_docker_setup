#!/bin/bash
set -e

mkdir -p logs

INSTALL_LOG="logs/install.log"
echo "$(date +"[%Y-%m-%d %H:%M:%S]") Starting setup" > "$INSTALL_LOG"

timestamp() {
  date +"[%Y-%m-%d %H:%M:%S]"
}

ensure_directories() {
  local dirs=("env" "logs" "plots" "backups" "python" "scripts" "systemd")

  for dir in "${dirs[@]}"; do
    if [ ! -d "$dir" ]; then
      echo "$(timestamp) WARNING: Folder '$dir' missing. Creating it..." | tee -a "$INSTALL_LOG"
      mkdir -p "$dir"
    else
      echo "$(timestamp) Found folder: $dir" | tee -a "$INSTALL_LOG"
    fi
  done
}

check_and_install() {
    local package=$1
    if ! dpkg -s "$package" >/dev/null 2>&1; then
        echo "$(timestamp) Installing missing package: $package..." | tee -a "$INSTALL_LOG"
        sudo apt-get install -y "$package" | tee -a "$INSTALL_LOG"
    else
        echo "$(timestamp) Dependency $package already installed." | tee -a "$INSTALL_LOG"
    fi
}

check_and_install_python() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo "$(timestamp) Installing Python3..." | tee -a "$INSTALL_LOG"
        sudo apt-get install -y python3 | tee -a "$INSTALL_LOG"
    else
        echo "$(timestamp) Python3 already installed." | tee -a "$INSTALL_LOG"
    fi
}

check_and_install_pip() {
    if ! command -v pip3 >/dev/null 2>&1; then
        echo "$(timestamp) Installing python3-pip..." | tee -a "$INSTALL_LOG"
        sudo apt-get install -y python3-pip | tee -a "$INSTALL_LOG"
    fi

    if ! command -v pip3 >/dev/null 2>&1; then
        echo "$(timestamp) pip3 still missing. Attempting manual installation..." | tee -a "$INSTALL_LOG"
        curl -sS https://bootstrap.pypa.io/get-pip.py -o get-pip.py | tee -a "$INSTALL_LOG"
        sudo python3 get-pip.py | tee -a "$INSTALL_LOG"
    fi

    if command -v pip3 >/dev/null 2>&1; then
        echo "$(timestamp) pip3 is ready." | tee -a "$INSTALL_LOG"
    else
        echo "$(timestamp) ERROR: pip3 installation failed." | tee -a "$INSTALL_LOG"
        exit 1
    fi
}

check_and_install_python_package() {
    local package=$1
    if ! python3 -c "import $package" >/dev/null 2>&1; then
        echo "$(timestamp) Installing missing Python package: $package..." | tee -a "$INSTALL_LOG"
        pip3 install "$package" | tee -a "$INSTALL_LOG"
    else
        echo "$(timestamp) Python package $package already installed." | tee -a "$INSTALL_LOG"
    fi
}

prompt_for_envs() {
  echo "$(timestamp) Checking environment configuration..." | tee -a "$INSTALL_LOG"
  mkdir -p env

  if [ ! -f env/drive_mount.env ]; then
    echo "Creating drive_mount.env:"
    read -p "Enter backup mount point (default /backups): " mount_point
    mount_point=${mount_point:-/backups}
    read -p "Enter backup drive UUID: " uuid
    echo "MOUNT_POINT=$mount_point" > env/drive_mount.env
    echo "DEVICE_UUID=$uuid" >> env/drive_mount.env
  fi

  if [ ! -f env/backup.env ]; then
    echo "Creating backup.env:"
    read -p "Enter backup folder path (default /backups): " backup_folder
    backup_folder=${backup_folder:-/backups}
    read -p "Enter backup retention days (default 14): " retention_days
    retention_days=${retention_days:-14}
    echo "BACKUP_FOLDER=$backup_folder" > env/backup.env
    echo "BACKUP_RETENTION_DAYS=$retention_days" >> env/backup.env
  fi

  if [ ! -f env/opendns.env ]; then
    echo "Creating opendns.env:"
    echo "DNS1=208.67.222.222" > env/opendns.env
    echo "DNS2=208.67.220.220" >> env/opendns.env
  fi

  if [ ! -f env/signal.env ]; then
    echo "Creating signal.env:"
    read -p "Enter your Signal CLI registered number (e.g., +15551234567): " signal_user
    read -p "Enter your Signal Group ID: " group_id
    read -p "Enter authorized sender numbers (comma-separated): " authorized_senders
    echo "SIGNAL_CLI_USER=$signal_user" > env/signal.env
    echo "SIGNAL_GROUP_ID=$group_id" >> env/signal.env
    echo "AUTHORIZED_SENDERS=$authorized_senders" >> env/signal.env
  fi
}

validate_env_vars() {
  local required_vars=(
    "MOUNT_POINT"
    "DEVICE_UUID"
    "BACKUP_FOLDER"
    "BACKUP_RETENTION_DAYS"
    "SIGNAL_CLI_USER"
    "SIGNAL_GROUP_ID"
    "AUTHORIZED_SENDERS"
  )

  local default_placeholder_values=(
    "your-drive-uuid-here"
    "+15551234567"
    "your-signal-group-id-here"
  )

  for var in "${required_vars[@]}"; do
    value="${!var}"

    if [ -z "$value" ]; then
      echo "$(timestamp) WARNING: '$var' is missing."
      read -rp "Enter value for $var: " user_value
      export $var="$user_value"
      sed -i "s|^$var=.*|$var=$user_value|" ./env/*.env
      continue
    fi

    for default in "${default_placeholder_values[@]}"; do
      if [[ "$value" == *"$default"* ]]; then
        echo "$(timestamp) WARNING: '$var' still has default value '$default'."
        read -rp "Enter corrected value for $var: " corrected_value
        export $var="$corrected_value"
        sed -i "s|^$var=.*|$var=$corrected_value|" ./env/*.env
        continue
      fi
    done
  done

  echo "$(timestamp) All environment variables are properly set." | tee -a "$INSTALL_LOG"
}

# -----------------
# Start Setup Flow
# -----------------

echo "$(timestamp) Checking project folders..." | tee -a "$INSTALL_LOG"
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

source ./env/drive_mount.env
source ./env/backup.env
source ./env/opendns.env
source ./env/signal.env

validate_env_vars

echo "$(timestamp) Running installation scripts..." | tee -a "$INSTALL_LOG"
./scripts/install_docker.sh
./scripts/install_nginx.sh
./scripts/setup_opendns.sh
./scripts/mount_drive.sh

if ! command -v signal-cli >/dev/null 2>&1; then
  echo "$(timestamp) Installing Signal CLI..." | tee -a "$INSTALL_LOG"
  ./scripts/install_signal_cli.sh
fi

echo "$(timestamp) Deploying Foundry container..." | tee -a "$INSTALL_LOG"
./scripts/install_foundry_docker.sh

echo "$(timestamp) Setup complete. You may now enable systemd services." | tee -a "$INSTALL_LOG"
