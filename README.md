
# Raspi FoundryVTT Docker Setup

**Production-grade automated deployment system** for running [Foundry Virtual Tabletop (FoundryVTT)](https://foundryvtt.com/) on a Raspberry Pi (4/5) using Docker, Nginx reverse proxy, DuckDNS dynamic DNS, and encrypted Signal CLI notifications.

---

## 🌟 Features

### **🚀 Core Automation**
- 🐳 **Production-ready FoundryVTT** deployment with resource optimization
- 🔧 **One-command installation** with comprehensive validation (`./setup.sh`)
- 🏗️ **Docker optimization** specifically tuned for Raspberry Pi hardware
- 🔄 **Automatic systemd integration** with timers and health monitoring
- 📦 **Multiple storage options** (USB, NFS, SMB) with smart mounting

### **🌐 Network & Access**
- 🌍 **DuckDNS dynamic DNS** with automatic IP updates and validation
- 🔒 **Nginx reverse proxy** with security headers and SSL-ready configuration
- � **Remote Signal CLI management** with encrypted command processing
- 🔐 **Secure external access** with optional HTTPS/SSL support

### **💾 Advanced Backup System**
- � **Compressed backups** with 60-70% space savings (tar.gz)
- ✅ **Backup verification** with SHA256 checksums and integrity testing
- � **Container-aware backups** with automatic pause/resume for consistency
- 📊 **Intelligent cleanup** with configurable retention and space monitoring
- 📱 **Signal notifications** for backup status and alerts

### **� Monitoring & Management**
- 🏥 **Comprehensive health checks** with container and service monitoring
- 📋 **Weekly automated reports** via Signal with system statistics
- 📈 **Resource monitoring** with memory, CPU, and disk usage tracking
- 🔧 **Management tools** with interactive menus and helper commands
- 📝 **Detailed logging** with rotation and centralized log management

### **🔒 Security & Reliability**
- �️ **Security hardening** with container isolation and privilege restrictions
- 🔥 **Firewall integration** with UFW configuration guidance
- 🔐 **SSL/TLS support** with Let's Encrypt integration
- 🔄 **Automatic updates** and system maintenance
- 📱 **Authorized-only access** via Signal number verification

---

## 🚀 Quick Start

### **Prerequisites**
- Raspberry Pi 4 or 5 (4GB+ RAM recommended)
- Raspberry Pi OS Lite (64-bit)
- External USB drive (optional, for backups)
- Signal account and phone number

### **Installation**

```bash
# Clone the repository
git clone https://github.com/Arch-Node/raspi_foundryvtt_docker_setup.git
cd raspi_foundryvtt_docker_setup

# Run the automated setup
chmod +x setup.sh
./setup.sh
```

### **What `setup.sh` Does**

✅ **System Preparation:**
- Installs and configures Docker with Pi-optimized settings
- Sets up Nginx reverse proxy with security headers
- Configures Python environment with required packages
- Creates directory structure and sets permissions

✅ **Storage Configuration:**
- Detects and mounts external drives (USB/NFS/SMB)
- Sets up backup directories with proper ownership
- Configures automated backup rotation and cleanup

✅ **Network Setup:**
- Configures DuckDNS dynamic DNS with validation
- Tests connectivity and credential verification
- Sets up monitoring and automatic IP updates

✅ **Signal CLI Integration:**
- Installs and configures Signal CLI daemon
- Sets up command listener service
- Provides registration guidance and testing tools

✅ **Container Deployment:**
- Deploys FoundryVTT with resource limits and health checks
- Configures backup volume integration
- Sets up container management and monitoring

✅ **Service Management:**
- Installs all systemd services and timers
- Enables automated tasks (backups, health checks, updates)
- Provides comprehensive management tools

---

## 📂 Enhanced Project Structure

| Folder / File | Purpose |
|:--------------|:--------|
| `env/` | Environment configuration files (credentials, settings) |
| `logs/` | System, backup, and health check logs |
| `plots/` | Future server metrics and performance graphs |
| `backups/` | Compressed FoundryVTT data backups with metadata |
| `python/` | Enhanced automation scripts with error handling |
| `scripts/` | Production-ready installation and management scripts |
| `systemd/` | Service definitions and timers for automation |
| `setup.sh` | **Enhanced** main setup with comprehensive validation |
| `foundry.sh` | Interactive server management menu |
| `foundry-container.sh` | Container lifecycle management script |
| `deployment_checklist.md` | **Updated** complete deployment guide |

---

## 🧹 Signal CLI Remote Management

Control your server remotely via encrypted Signal messages:

| Command | Action | Description |
|:--------|:-------|:------------|
| `!foundry status` | Container status | Shows running status, health, and resource usage |
| `!foundry restart` | Restart container | Safely restarts the FoundryVTT container |
| `!foundry health` | Health check | Runs comprehensive system health diagnostics |
| `!foundry backup` | Manual backup | Creates immediate backup with verification |
| `!foundry uptime` | System uptime | Shows Pi uptime and container runtime |
| `!foundry space` | Disk usage | Displays disk space and backup storage status |
| `!foundry reboot` | System reboot | Safely reboots the Raspberry Pi |
| `!foundry help` | Command list | Displays all available commands |

🔐 **Security**: Only authorized Signal numbers (defined in `signal.env`) can send commands.

---

## 🛠 Management Tools

The enhanced setup provides comprehensive management tools:

### **Container Management**
```bash
./foundry.sh                    # Interactive management menu
./foundry-container.sh status   # Detailed container status
docker-status status            # Docker system overview
```

### **Signal Management**
```bash
foundry-signal status          # Signal services status
foundry-signal test            # Test Signal connectivity
foundry-signal logs            # View Signal daemon logs
```

### **DuckDNS Management**
```bash
duckdns-status status          # Check DNS resolution and IPs
duckdns-status update          # Force manual DNS update
duckdns-status logs            # View update history
```

### **Backup Management**
```bash
python3 python/backup_now.py   # Create manual backup
# View backup logs in /backups/logs/
```

### **System Monitoring**
```bash
sudo systemctl list-timers     # View all automated tasks
journalctl -u foundryvtt-container.service  # Container logs
```

---

## 📊 Enhanced Features

### **Backup System**
- **Compression**: 60-70% space savings with tar.gz
- **Verification**: SHA256 checksums and integrity testing
- **Container-aware**: Pauses container during backup for consistency
- **Retention**: Configurable cleanup with space tracking
- **Monitoring**: Signal alerts for backup success/failure

### **Network Access**
- **Local**: `http://your-pi-ip:29000`
- **External**: `http://yourdomain.duckdns.org:29000`
- **HTTPS**: `https://yourdomain.duckdns.org:29000` (with SSL)
- **Nginx**: `http://your-pi-ip` (reverse proxy)

### **Resource Optimization**
- **Memory limits**: 2GB container limit with 3GB swap
- **CPU limits**: 2.0 CPU cores to prevent overheating
- **Log rotation**: Automatic cleanup to preserve SD card life
- **Health monitoring**: HTTP endpoint checks every 30 seconds

---

## 📋 Deployment Guide

See [`deployment_checklist.md`](deployment_checklist.md) for comprehensive step-by-step instructions including:

### **Complete Setup Process:**
- 🛠 Raspberry Pi OS preparation and optimization
- 🔧 Automated installation with validation
- 🔐 Signal CLI registration and testing
- 🌐 DuckDNS configuration and verification
- 📡 Router port forwarding setup
- 🔒 SSL/HTTPS configuration (optional)
- 🛡️ Security hardening and firewall setup

### **Validation & Testing:**
- ✅ Local and external access testing
- ✅ Signal command verification
- ✅ Backup system validation
- ✅ Health monitoring confirmation
- ✅ Performance optimization verification

### **Troubleshooting:**
- 🔍 Common issue resolution
- 📊 Log analysis and debugging
- 🔧 Service management and restart procedures
- 📱 Signal connectivity troubleshooting

---

## 🔧 Configuration

### **Environment Files (`env/` directory):**
- `foundry.env` - Container settings, ports, credentials
- `backup.env` - Backup retention, compression, verification
- `signal.env` - Signal CLI user, group, authorized numbers
- `duckdns.env` - Domain name and authentication token
- `drive_mount.env` - Storage configuration (USB/NFS/SMB)

### **Advanced Configuration:**
```bash
# backup.env
BACKUP_TYPE=full                    # full or incremental
COMPRESS_BACKUPS=true              # Enable compression
VERIFY_BACKUPS=true                # Enable integrity checks
MAX_BACKUP_SIZE_GB=10              # Size limit warnings

# foundry.env (auto-configured)
FOUNDRY_PORT_PUBLIC=29000          # External access port
FOUNDRY_PORT_INTERNAL=30000        # Container internal port
FOUNDRY_IMAGE=felddy/foundryvtt:release
```

---

## 🆘 Support & Troubleshooting

### **Built-in Diagnostics:**
```bash
# Quick health check
duckdns-status status && foundry-signal status && docker-status status

# View recent logs
tail -f /backups/logs/backup_$(date +%Y%m%d).log
journalctl -u signal-cli.service -f
```

### **Common Solutions:**
- **Container issues**: Check `docker logs foundryvtt-release`
- **Signal problems**: Run `foundry-signal test`
- **DNS issues**: Check `duckdns-status status`
- **Backup failures**: Review `/backups/logs/`

---

## 📜 License

This project is licensed under the MIT License.  
Feel free to use, modify, and improve!

---

## 📬 Contributions Welcome!

Issues, Pull Requests, and Suggestions are welcome!  
Let's make this the **best production-grade** Raspberry Pi FoundryVTT deployment system together.

### **Contributing:**
- 🐛 **Bug Reports**: Issues with clear reproduction steps
- 💡 **Feature Requests**: Ideas for new functionality
- 🔧 **Pull Requests**: Code improvements and new features
- 📚 **Documentation**: Help improve setup guides and troubleshooting

---

**🎯 This system is production-ready and provides enterprise-grade reliability for your FoundryVTT games!**

---

## 📜 License

This project is licensed under the MIT License.  
Feel free to use, modify, and improve!

---

## 📬 Contributions Welcome!

Issues, Pull Requests, and Suggestions are welcome!  
Let's make this the best Raspberry Pi FoundryVTT deployment system together.

---
