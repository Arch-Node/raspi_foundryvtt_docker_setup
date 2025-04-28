#!/bin/bash
# Interactive SSH server management menu script.

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function print_menu() {
  echo -e "${CYAN}"
  echo "======================================"
  echo "   FoundryVTT Server Management Menu   "
  echo "======================================"
  echo -e "${NC}"
  echo "1) Check for FoundryVTT Updates"
  echo "2) Backup Foundry Data Now"
  echo "3) Update Foundry and Backup"
  echo "4) Run Health Check"
  echo "5) View Maintenance Logs"
  echo "6) View Backup Drive Space"
  echo "7) Trigger Weekly Health Report Now"
  echo "8) View Last Health Report Timestamp"
  echo "9) Restart Foundry Container"
  echo "10) Reboot Server"
  echo "0) Exit"
  echo ""
}

function pause() {
  read -rp "Press [Enter] key to continue..." fackEnterKey
}

function check_updates() {
  echo -e "${YELLOW}Checking for Foundry updates...${NC}"
  python3 ./python/check_and_update_foundry.py
  pause
}

function backup_now() {
  echo -e "${YELLOW}Creating backup...${NC}"
  # You can call your backup script or tar command here
  tar czf /backups/foundry_backup_"$(date +%Y%m%d_%H%M%S)".tar.gz /home/foundryuser/foundrydata
  echo -e "${GREEN}Backup complete.${NC}"
  pause
}

function update_and_backup() {
  echo -e "${YELLOW}Backing up and checking for updates...${NC}"
  backup_now
  check_updates
}

function run_health_check() {
  echo -e "${YELLOW}Running health check...${NC}"
  python3 ./python/health_check.py
  pause
}

function view_logs() {
  echo -e "${CYAN}Showing latest maintenance log:${NC}"
  less logs/maintenance.log
}

function view_backup_space() {
  echo -e "${CYAN}Backup Drive Space:${NC}"
  df -h /backups
  pause
}

function trigger_weekly_report() {
  echo -e "${YELLOW}Sending weekly health report now...${NC}"
  python3 ./python/weekly_health_report.py
  pause
}

function view_health_timestamp() {
  echo -e "${CYAN}Last Health Check Timestamp:${NC}"
  ls -lh logs/health_check.log
  pause
}

function restart_foundry() {
  echo -e "${YELLOW}Restarting FoundryVTT container...${NC}"
  docker restart foundryvtt
  pause
}

function reboot_server() {
  echo -e "${RED}WARNING: Server will reboot immediately!${NC}"
  read -p "Type 'rebootnow' to confirm: " confirm
  if [[ "$confirm" == "rebootnow" ]]; then
    sudo reboot
  else
    echo -e "${YELLOW}Reboot cancelled.${NC}"
    pause
  fi
}

# Main Menu Loop
while true; do
  clear
  print_menu
  read -rp "Enter your choice [0-10]: " choice
  case $choice in
    1) check_updates ;;
    2) backup_now ;;
    3) update_and_backup ;;
    4) run_health_check ;;
    5) view_logs ;;
    6) view_backup_space ;;
    7) trigger_weekly_report ;;
    8) view_health_timestamp ;;
    9) restart_foundry ;;
    10) reboot_server ;;
    0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
    *) echo -e "${RED}Invalid option...${NC}" && sleep 1 ;;
  esac
done
