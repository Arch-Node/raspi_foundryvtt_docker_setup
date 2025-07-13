#!/bin/bash
# =============================================================================
#  check_host.sh - System Readiness Checker for Raspi FoundryVTT Podman Setup
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function check() {
  if "$@" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} $*"
  else
    echo -e "${RED}[MISSING]${NC} $*"
    return 1
  fi
}

function check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} $1"
  else
    echo -e "${RED}[MISSING]${NC} $1"
    return 1
  fi
}

function check_python_package() {
  if python3 -c "import $1" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} Python package: $1"
  else
    echo -e "${RED}[MISSING]${NC} Python package: $1"
    return 1
  fi
}

function check_file() {
  if [ -f "$1" ]; then
    echo -e "${GREEN}[OK]${NC} $1 exists"
  else
    echo -e "${YELLOW}[WARN]${NC} $1 missing"
    return 1
  fi
}

function check_dir() {
  if [ -d "$1" ]; then
    echo -e "${GREEN}[OK]${NC} $1 exists"
  else
    echo -e "${YELLOW}[WARN]${NC} $1 missing"
    return 1
  fi
}

function check_disk_space() {
  local dir="$1"
  local min_gb="$2"
  local avail_gb=$(df -BG "$dir" | awk 'NR==2 {gsub("G", "", $4); print $4}')
  if [ "$avail_gb" -ge "$min_gb" ]; then
    echo -e "${GREEN}[OK]${NC} $avail_gb GB free on $dir"
  else
    echo -e "${RED}[LOW]${NC} Only $avail_gb GB free on $dir (need at least $min_gb GB)"
    return 1
  fi
}

# --- System Info ---
echo -e "\n===== System Information ====="
echo "Hostname: $(hostname)"
echo "OS: $(uname -a)"
echo "Architecture: $(uname -m)"
echo "User: $(whoami)"

# --- Core Dependencies ---
echo -e "\n===== Core Dependencies ====="
check_command podman
check_command podman-compose || check_command podman compose
check_command python3
check_command pip3
check_command curl
check_command git
check_command systemctl
check_command nginx

# --- Python Packages ---
echo -e "\n===== Python Packages ====="
check_python_package requests
check_python_package dotenv

# --- Signal CLI ---
echo -e "\n===== Signal CLI ====="
if command -v signal-cli >/dev/null 2>&1; then
  echo -e "${GREEN}[OK]${NC} signal-cli installed"
  signal-cli --version || true
else
  echo -e "${RED}[MISSING]${NC} signal-cli not installed"
fi

# --- Environment Files ---
echo -e "\n===== Environment Files ====="
check_dir env
check_file env/drive_mount.env
check_file env/backup.env
check_file env/signal.env
check_file env/duckdns.env
check_file env/foundry.env

# --- Disk Space ---
echo -e "\n===== Disk Space ====="
check_disk_space "/" 5

# --- Podman Image Architecture ---
echo -e "\n===== Podman Image Architecture ====="
if [ -f env/foundry.env ]; then
  IMAGE=$(grep FOUNDRY_IMAGE env/foundry.env | cut -d= -f2)
  if [ -n "$IMAGE" ]; then
    echo "FoundryVTT Podman image: $IMAGE"
    echo "Checking image architecture (may take a moment)..."
    podman image inspect "$IMAGE" >/dev/null 2>&1 || podman pull "$IMAGE"
    ARCH=$(podman image inspect "$IMAGE" | grep 'Architecture' | head -1 | awk -F '"' '{print $4}')
    echo "Image architecture: $ARCH (Host: $(uname -m))"
    if [ "$ARCH" != "$(uname -m)" ]; then
      echo -e "${YELLOW}[WARN]${NC} Image architecture does not match host!"
    fi
  fi
else
  echo "env/foundry.env not found, cannot check image."
fi

# --- Systemd Services ---
echo -e "\n===== Systemd Services ====="
for svc in foundryvtt-container.service signal-cli.service signal-listener.service duckdns.service; do
  if systemctl list-unit-files | grep -q "$svc"; then
    echo -e "${GREEN}[OK]${NC} $svc installed"
  else
    echo -e "${YELLOW}[WARN]${NC} $svc not installed"
  fi
  if systemctl is-active --quiet "$svc"; then
    echo -e "${GREEN}[RUNNING]${NC} $svc"
  else
    echo -e "${YELLOW}[INACTIVE]${NC} $svc"
  fi
  echo
done

# --- Summary ---
echo -e "\n===== Summary ====="
echo "Review any [MISSING] or [LOW] items above before running ./setup.sh."
echo "If all [OK], you are ready to build and test with Podman!"
