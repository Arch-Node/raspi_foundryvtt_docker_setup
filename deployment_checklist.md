
# 📋 Deployment Checklist

Follow these steps to fully deploy your FoundryVTT server on Raspberry Pi:

---

## 🛠 Raspberry Pi Initial Setup

- [ ] Flash Raspberry Pi OS Lite (64-bit) onto an SD card using Raspberry Pi Imager
- [ ] Boot the Pi and complete initial system configuration
- [ ] Run `sudo raspi-config` and:
  - [ ] Expand filesystem
  - [ ] Set hostname (optional, e.g., `foundryvtt-pi`)
  - [ ] Configure WiFi (if needed)
  - [ ] Enable SSH for remote access
- [ ] Update system:
  ```bash
  sudo apt-get update && sudo apt-get upgrade -y
  ```
- [ ] **Reboot** if kernel updates were installed:
  ```bash
  sudo reboot
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

- [ ] **IMPORTANT**: Prepare your external drive (if using):
  - [ ] Connect USB drive to Pi
  - [ ] Find UUID: `sudo blkid`
  - [ ] Note the UUID for setup

- [ ] Run the automated setup:
  ```bash
  ./setup.sh
  ```

✅ **Enhanced Setup Process** now includes:
- ✅ Comprehensive dependency installation with error handling
- ✅ Optimized Docker configuration for Raspberry Pi
- ✅ Production-ready Nginx reverse proxy with security headers
- ✅ Complete Signal CLI setup with daemon services
- ✅ DuckDNS configuration with validation and monitoring
- ✅ Storage mounting (USB/NFS/SMB) with integrity checks
- ✅ Enhanced backup system with compression and verification
- ✅ All systemd services automatically installed and enabled
- ✅ Container deployment with resource limits and health checks

---

## � Post-Setup Configuration

### **Signal CLI Registration** (if not completed during setup):
- [ ] Complete Signal CLI registration:
  ```bash
  foundry-signal register
  foundry-signal verify CODE_FROM_SMS
  foundry-signal test
  ```

### **DuckDNS Validation**:
- [ ] Verify DuckDNS is working:
  ```bash
  duckdns-status status
  ```
- [ ] Check your domain resolves correctly:
  ```bash
  nslookup yourdomain.duckdns.org
  ```

### **Router Configuration**:
- [ ] **Configure port forwarding** on your router:
  - [ ] Forward port `29000` (or your custom port) to Pi's IP
  - [ ] Forward port `80` (for Nginx) to Pi's IP *(optional)*
  - [ ] Forward port `443` (for HTTPS) to Pi's IP *(optional)*

---

## 🧪 Testing and Validation

### **Local Testing**:
- [ ] Test FoundryVTT access locally:
  ```
  http://your-pi-ip:29000
  ```
- [ ] Test Nginx reverse proxy:
  ```
  http://your-pi-ip
  ```

### **External Testing**:
- [ ] Test DuckDNS domain access:
  ```
  http://yourdomain.duckdns.org:29000
  ```
- [ ] Test from mobile data or external network

### **Signal Testing**:
- [ ] Send test Signal commands:
  - [ ] `!foundry status`
  - [ ] `!foundry health`
  - [ ] `!foundry help`

### **Backup Testing**:
- [ ] Test manual backup:
  ```bash
  python3 python/backup_to_gdrive.py
  ```
- [ ] Verify backup files in backup directory
- [ ] Check backup logs:
  ```bash
  ls -la /backups/logs/
  ```

---

## 📊 System Monitoring

### **Service Status Checks**:
- [ ] Check all systemd timers are active:
  ```bash
  sudo systemctl list-timers | grep -E "(foundry|backup|health|reboot)"
  ```

- [ ] Verify Docker status:
  ```bash
  docker-status status
  ```

- [ ] Check container health:
  ```bash
  docker ps
  docker stats --no-stream
  ```

### **Available Management Commands**:
```bash
# FoundryVTT Management
./foundry.sh                    # Interactive management menu
./foundry-container.sh status   # Container status and resources

# Signal Management  
foundry-signal status          # Signal services status
foundry-signal logs            # View Signal logs

# DuckDNS Management
duckdns-status status          # Check DNS resolution
duckdns-status logs            # View update logs

# Docker Management
docker-status status           # Overall Docker status
docker-status stats            # Resource usage
docker-status cleanup          # Manual cleanup

# Backup Management
python3 python/backup_now.py   # Manual backup
```

---

## 🔒 Security Hardening (Optional)

### **SSL/HTTPS Setup**:
- [ ] Install Certbot for Let's Encrypt:
  ```bash
  sudo apt-get install certbot python3-certbot-nginx
  ```
- [ ] Obtain SSL certificate:
  ```bash
  sudo certbot --nginx -d yourdomain.duckdns.org
  ```
- [ ] Set up automatic renewal:
  ```bash
  sudo systemctl enable certbot.timer
  ```

### **Firewall Configuration**:
- [ ] Install and configure UFW:
  ```bash
  sudo apt-get install ufw
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow ssh
  sudo ufw allow 29000
  sudo ufw allow 80
  sudo ufw allow 443
  sudo ufw enable
  ```

### **Additional Security**:
- [ ] Change default SSH port (optional)
- [ ] Set up SSH key authentication
- [ ] Disable password authentication for SSH
- [ ] Regular system updates via unattended-upgrades

---

## 📱 Optional Enhancements

### **Google Drive Backups**:
- [ ] Set up Google Drive API credentials
- [ ] Configure `backup_to_gdrive.py` script
- [ ] Test automated cloud backups

### **Advanced Monitoring**:
- [ ] Set up Prometheus metrics collection
- [ ] Configure Grafana dashboards
- [ ] Add custom health check endpoints

### **Multi-Container Setup**:
- [ ] Deploy additional game systems
- [ ] Set up container orchestration
- [ ] Implement load balancing

---

## 🎯 Final Validation Checklist

- [ ] ✅ FoundryVTT accessible locally and externally
- [ ] ✅ DuckDNS domain resolves correctly  
- [ ] ✅ Signal commands working from authorized numbers
- [ ] ✅ Automated backups running and verified
- [ ] ✅ All systemd timers active and healthy
- [ ] ✅ Docker containers running with proper resource limits
- [ ] ✅ Nginx reverse proxy functioning
- [ ] ✅ Log rotation and cleanup working
- [ ] ✅ Health monitoring and alerting active

---

## 📞 Troubleshooting

### **Common Issues**:

**Container Won't Start:**
```bash
docker logs foundryvtt-release
docker-status status
```

**Signal Not Working:**
```bash
foundry-signal status
journalctl -u signal-cli.service -f
```

**DuckDNS Not Updating:**
```bash
duckdns-status status
duckdns-status logs
```

**Backup Failures:**
```bash
cat /backups/logs/backup_$(date +%Y%m%d).log
python3 python/backup_now.py
```

### **Log Locations**:
- FoundryVTT Container: `docker logs foundryvtt-release`
- Backup Logs: `/backups/logs/`
- DuckDNS Logs: `/var/log/duckdns/update.log`
- Signal Logs: `journalctl -u signal-cli.service`
- System Logs: `journalctl -xe`

---

# ✅ Congratulations!

Your **production-grade FoundryVTT server** is now:
- 🚀 **Fully automated** with comprehensive monitoring
- 🔐 **Secure** with proper hardening and access controls  
- 📱 **Remotely manageable** via Signal commands
- 💾 **Automatically backed up** with verification and retention
- 🌐 **Externally accessible** via DuckDNS with optional HTTPS
- 📊 **Well monitored** with logging and health checks
- 🔄 **Self-maintaining** with automated updates and cleanup

**Your players can now connect using:**
- **Local**: `http://your-pi-ip:29000`
- **External**: `http://yourdomain.duckdns.org:29000`
- **HTTPS** (if configured): `https://yourdomain.duckdns.org:29000`

---
