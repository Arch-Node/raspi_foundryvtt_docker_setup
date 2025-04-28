
# Raspi FoundryVTT Docker Setup

Automated deployment system for running [Foundry Virtual Tabletop (FoundryVTT)](https://foundryvtt.com/) on a Raspberry Pi (4/5) using Docker, Nginx, OpenDNS, and encrypted Signal CLI notifications.

---

## 📦 Features

- 🐳 Deploys FoundryVTT in Docker automatically
- 🔒 Enforces OpenDNS security
- 📋 Weekly automated server health reports via Signal
- 🛠 Daily health checks and backup rotation
- 🚀 One-command full installation (`./setup.sh`)
- 📈 Web-accessible metrics and maintenance logs
- 📦 Weekly push-ready for Google Drive backup (optional)
- 📱 Remote container control via Signal commands (restart, health check, reboot)
- 📋 Systemd timers for automatic tasks

---

## 🚀 Quick Start

Clone the repository:

```bash
git clone https://github.com/Arch-Node/raspi_foundryvtt_docker_setup.git
cd raspi_foundryvtt_docker_setup

# Make setup executable
chmod +x setup.sh

# Run the setup interactively
./setup.sh
```

✅ `setup.sh` will:

- Check for all system dependencies
- Prompt for missing or invalid `.env` values
- Install Docker, Nginx, OpenDNS, Signal CLI
- Deploy the FoundryVTT server container
- Setup systemd services and timers

---

## 📂 Folder Structure

| Folder / File | Purpose |
|:--------------|:--------|
| `env/` | Environment configuration files |
| `logs/` | Health and maintenance logs |
| `plots/` | Future server graphs and metrics |
| `backups/` | Foundry data backups |
| `python/` | Python automation scripts |
| `scripts/` | Shell install/maintenance scripts |
| `systemd/` | Timers and services |
| `setup.sh` | Main setup and validation script |
| `foundry.sh` | Interactive server management menu |
| `deployment_checklist.md` | Full deployment guide |
| `.gitignore` | Ignore runtime/generated files |

---

## 🧹 Signal CLI Commands

Once installed, Signal users can manage the server remotely:

| Command | Action |
|:--------|:-------|
| `!foundry status` | View container status |
| `!foundry restart` | Restart the Foundry container |
| `!foundry health` | Run a live health check |
| `!foundry backup` | Force a manual backup |
| `!foundry uptime` | View server uptime |
| `!foundry space` | Check backup disk space |
| `!foundry reboot` | Reboot the Raspberry Pi |
| `!foundry help` | Display command list |

✅ Only authorized Signal numbers (defined in `signal.env`) can send these commands.

---

## 📋 Deployment Checklist

See [`deployment_checklist.md`](deployment_checklist.md) for step-by-step instructions:
- Setting up Raspberry Pi OS Lite
- Installing Docker & pre-reqs
- Cloning this repository
- Running `setup.sh`
- Enabling systemd services
- Setting up Google Drive backups (optional)

---

## 📜 License

This project is licensed under the MIT License.  
Feel free to use, modify, and improve!

---

## 📬 Contributions Welcome!

Issues, Pull Requests, and Suggestions are welcome!  
Let's make this the best Raspberry Pi FoundryVTT deployment system together.

---
