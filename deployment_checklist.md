
# 📋 Deployment Checklist

Follow these steps to fully deploy your FoundryVTT server on Raspberry Pi:

---

## 🛠 Raspberry Pi Initial Setup

- [ ] Flash Raspberry Pi OS Lite (64-bit) onto an SD card using Raspberry Pi Imager
- [ ] Boot the Pi and complete initial system configuration
- [ ] Run `sudo raspi-config` and:
  - [ ] Expand filesystem
  - [ ] Set hostname (optional)
  - [ ] Configure WiFi (if needed)
  - [ ] Enable SSH for remote access
- [ ] Update system:
  ```bash
  sudo apt-get update && sudo apt-get upgrade -y
  ```

---

## 🔥 Clone and Set Up Project

- [ ] Install Git if missing:
  ```bash
  sudo apt-get install git -y
  ```

- [ ] Clone this repository:
  ```bash
  git clone https://github.com/Arch-Node/raspi_foundryvtt_docker_setup.git
  cd raspi_foundryvtt_docker_setup
  ```

- [ ] Make the setup script executable:
  ```bash
  chmod +x setup.sh
  ```

- [ ] Run the setup interactively:
  ```bash
  ./setup.sh
  ```

✅ This will:
- Check and install system dependencies
- Install Docker, Nginx, OpenDNS configuration
- Install Signal CLI
- Prompt for environment variable setup
- Validate configuration automatically
- Deploy FoundryVTT container

---

## 🛠 Enable Systemd Services

- [ ] Copy systemd service and timer files:
  ```bash
  sudo cp systemd/*.service /etc/systemd/system/
  sudo cp systemd/*.timer /etc/systemd/system/
  ```

- [ ] Reload systemd:
  ```bash
  sudo systemctl daemon-reload
  ```

- [ ] Enable and start timers:
  ```bash
  sudo systemctl enable check_and_update_foundry.timer
  sudo systemctl start check_and_update_foundry.timer

  sudo systemctl enable rotate_backups.timer
  sudo systemctl start rotate_backups.timer

  sudo systemctl enable weekly_health_report.timer
  sudo systemctl start weekly_health_report.timer

  sudo systemctl enable weekly_reboot.timer
  sudo systemctl start weekly_reboot.timer
  ```

---

## 🧹 Final Post-Deployment

- [ ] Test access to FoundryVTT via browser:
  ```
  http://your-pi-ip:29000
  ```

- [ ] Test Signal CLI by sending a message to group
- [ ] (Optional) Configure backups to Google Drive (future work)
- [ ] (Optional) Set up HTTPS with Let's Encrypt for Nginx reverse proxy

---

# ✅ Congratulations!

Your FoundryVTT server is live and self-maintaining!

---
