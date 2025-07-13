#!/bin/bash
# =============================================================================
#  setup_duckdns.sh - Setup DuckDNS Updater for Dynamic IP Resolution
#
#  Author: Arch-Node Project
#  Purpose:
#    - Configure automatic IP updates with DuckDNS
#    - Validate DuckDNS credentials and connectivity
#    - Set up robust monitoring and logging
#    - Integrate with FoundryVTT setup
#
#  Usage:
#    ./scripts/setup_duckdns.sh
#
# =============================================================================

set -e

# Load environment variables
if [ -f ./env/duckdns.env ]; then
    export $(grep -v '^#' ./env/duckdns.env | xargs)
elif [ -f ../env/duckdns.env ]; then
    export $(grep -v '^#' ../env/duckdns.env | xargs)
else
    echo "[ERROR] Missing env/duckdns.env. Cannot configure DuckDNS."
    echo "[INFO] Please create env/duckdns.env with:"
    echo "       DUCKDNS_DOMAIN=yourdomain"
    echo "       DUCKDNS_TOKEN=your-token"
    exit 1
fi

# Validate required variables
if [ -z "$DUCKDNS_DOMAIN" ] || [ -z "$DUCKDNS_TOKEN" ]; then
    echo "[ERROR] DUCKDNS_DOMAIN and DUCKDNS_TOKEN are required!"
    echo "[INFO] Please set these in env/duckdns.env"
    exit 1
fi

echo "[INFO] =============================================="
echo "[INFO] DuckDNS Dynamic DNS Setup"
echo "[INFO] =============================================="
echo "[INFO] Domain: ${DUCKDNS_DOMAIN}.duckdns.org"
echo "[INFO] Token: ${DUCKDNS_TOKEN:0:8}..." # Show only first 8 chars for security
echo "[INFO] =============================================="

# Install curl if not present
if ! command -v curl >/dev/null 2>&1; then
    echo "[INFO] Installing curl..."
    sudo apt-get update
    sudo apt-get install -y curl
fi

# Create folder for DuckDNS script and logs
sudo mkdir -p /opt/duckdns
sudo mkdir -p /var/log/duckdns

# Test DuckDNS credentials before setting up
echo "[INFO] Testing DuckDNS credentials and connectivity..."
TEST_RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=" || echo "FAILED")

if [[ "$TEST_RESPONSE" == "OK" ]]; then
    echo "[INFO] ✅ DuckDNS credentials validated successfully!"
elif [[ "$TEST_RESPONSE" == "KO" ]]; then
    echo "[ERROR] ❌ DuckDNS credentials invalid! Please check your domain and token."
    exit 1
else
    echo "[ERROR] ❌ Failed to connect to DuckDNS. Response: $TEST_RESPONSE"
    echo "[INFO] This could be a network issue. Continuing with setup..."
fi

# Get current public IP for verification
echo "[INFO] Detecting current public IP..."
PUBLIC_IP=$(curl -s https://ipv4.icanhazip.com/ 2>/dev/null || curl -s https://api.ipify.org 2>/dev/null || echo "unknown")
if [ "$PUBLIC_IP" != "unknown" ]; then
    echo "[INFO] Current public IP: $PUBLIC_IP"
else
    echo "[WARNING] Could not detect public IP. This may indicate network issues."
fi

# Create enhanced update script with logging and error handling
sudo tee /opt/duckdns/duck.sh >/dev/null <<EOF
#!/bin/bash
# DuckDNS Update Script with Enhanced Logging

DOMAIN="${DUCKDNS_DOMAIN}"
TOKEN="${DUCKDNS_TOKEN}"
LOG_FILE="/var/log/duckdns/update.log"
MAX_LOG_SIZE=10485760  # 10MB

# Function to log with timestamp
log_message() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') [\$1] \$2" >> "\$LOG_FILE"
}

# Rotate log if it gets too large
if [ -f "\$LOG_FILE" ] && [ \$(stat -c%s "\$LOG_FILE") -gt \$MAX_LOG_SIZE ]; then
    mv "\$LOG_FILE" "\$LOG_FILE.old"
    touch "\$LOG_FILE"
fi

# Get current IP before update
OLD_IP=\$(dig +short \${DOMAIN}.duckdns.org 2>/dev/null || echo "unknown")

# Perform DuckDNS update
RESPONSE=\$(curl -s "https://www.duckdns.org/update?domains=\${DOMAIN}&token=\${TOKEN}&ip=")

# Get new IP after update
sleep 2
NEW_IP=\$(curl -s https://ipv4.icanhazip.com/ 2>/dev/null || curl -s https://api.ipify.org 2>/dev/null || echo "unknown")

# Log results
if [ "\$RESPONSE" = "OK" ]; then
    if [ "\$OLD_IP" != "\$NEW_IP" ]; then
        log_message "INFO" "IP updated successfully: \$OLD_IP -> \$NEW_IP"
    else
        log_message "INFO" "IP confirmed current: \$NEW_IP"
    fi
    exit 0
else
    log_message "ERROR" "Update failed. Response: \$RESPONSE"
    exit 1
fi
EOF

# Make script executable
sudo chmod 700 /opt/duckdns/duck.sh

echo "[INFO] Enhanced DuckDNS updater script created at /opt/duckdns/duck.sh"

# Create systemd service with better configuration
sudo tee /etc/systemd/system/duckdns.service >/dev/null <<EOF
[Unit]
Description=DuckDNS Update Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=/opt/duckdns/duck.sh
StandardOutput=journal
StandardError=journal

# Timeout and restart settings
TimeoutStartSec=30
TimeoutStopSec=10

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/duckdns
PrivateTmp=true
EOF

# Create systemd timer with more frequent updates
sudo tee /etc/systemd/system/duckdns.timer >/dev/null <<EOF
[Unit]
Description=Run DuckDNS update script every 5 minutes
Requires=duckdns.service

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Unit=duckdns.service
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Set up log rotation for DuckDNS logs
sudo tee /etc/logrotate.d/duckdns >/dev/null <<EOF
/var/log/duckdns/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

# Create DuckDNS management script
echo "[INFO] Creating DuckDNS management helper..."
sudo tee /usr/local/bin/duckdns-status >/dev/null <<EOF
#!/bin/bash
# DuckDNS Status and Management Helper

DOMAIN="${DUCKDNS_DOMAIN}"
LOG_FILE="/var/log/duckdns/update.log"

case "\$1" in
    "status")
        echo "=== DuckDNS Service Status ==="
        systemctl status duckdns.timer --no-pager
        echo ""
        echo "=== Current IP Resolution ==="
        RESOLVED_IP=\$(dig +short \${DOMAIN}.duckdns.org 2>/dev/null || echo "Failed to resolve")
        PUBLIC_IP=\$(curl -s https://ipv4.icanhazip.com/ 2>/dev/null || echo "Failed to detect")
        echo "Domain: \${DOMAIN}.duckdns.org"
        echo "Resolved IP: \$RESOLVED_IP"
        echo "Public IP: \$PUBLIC_IP"
        if [ "\$RESOLVED_IP" = "\$PUBLIC_IP" ]; then
            echo "Status: ✅ IP addresses match"
        else
            echo "Status: ⚠️  IP addresses differ"
        fi
        ;;
    "logs")
        if [ -f "\$LOG_FILE" ]; then
            echo "=== Recent DuckDNS Updates ==="
            tail -20 "\$LOG_FILE"
        else
            echo "No DuckDNS logs found at \$LOG_FILE"
        fi
        ;;
    "update")
        echo "Running manual DuckDNS update..."
        /opt/duckdns/duck.sh
        echo "Update completed. Check logs for results."
        ;;
    "test")
        echo "Testing DuckDNS configuration..."
        RESPONSE=\$(curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=")
        if [ "\$RESPONSE" = "OK" ]; then
            echo "✅ DuckDNS test successful"
        else
            echo "❌ DuckDNS test failed: \$RESPONSE"
        fi
        ;;
    "restart")
        echo "Restarting DuckDNS timer..."
        sudo systemctl restart duckdns.timer
        echo "DuckDNS timer restarted."
        ;;
    *)
        echo "DuckDNS Management Helper"
        echo "Usage: duckdns-status {status|logs|update|test|restart}"
        echo ""
        echo "Commands:"
        echo "  status  - Show service status and IP comparison"
        echo "  logs    - Show recent update logs"
        echo "  update  - Force manual update"
        echo "  test    - Test DuckDNS credentials"
        echo "  restart - Restart the DuckDNS timer"
        ;;
esac
EOF

sudo chmod +x /usr/local/bin/duckdns-status

# Reload systemd and start timer
echo "[INFO] Enabling and starting DuckDNS services..."
sudo systemctl daemon-reload
sudo systemctl enable duckdns.timer
sudo systemctl start duckdns.timer

# Wait a moment and verify
sleep 3

# Check if timer is active
if systemctl is-active --quiet duckdns.timer; then
    echo "[INFO] ✅ DuckDNS timer is active and running."
else
    echo "[ERROR] ❌ DuckDNS timer failed to start!"
    systemctl status duckdns.timer --no-pager
    exit 1
fi

# Run initial update
echo "[INFO] Running initial DuckDNS update..."
sudo /opt/duckdns/duck.sh

# Verify update worked
sleep 5
RESOLVED_IP=$(dig +short ${DUCKDNS_DOMAIN}.duckdns.org 2>/dev/null || echo "unknown")

echo "[INFO] =============================================="
echo "[INFO] 🎉 DuckDNS Setup Complete! 🎉"
echo "[INFO] =============================================="
echo "[INFO]"
echo "[INFO] Configuration:"
echo "[INFO] - Domain: ${DUCKDNS_DOMAIN}.duckdns.org"
echo "[INFO] - Current IP: $PUBLIC_IP"
echo "[INFO] - Resolved IP: $RESOLVED_IP"
echo "[INFO] - Update Interval: 5 minutes"
echo "[INFO]"
echo "[INFO] Management Commands:"
echo "[INFO] - duckdns-status status   (check status and IPs)"
echo "[INFO] - duckdns-status logs     (view update logs)"
echo "[INFO] - duckdns-status update   (force manual update)"
echo "[INFO] - duckdns-status test     (test credentials)"
echo "[INFO] - duckdns-status restart  (restart service)"
echo "[INFO]"
echo "[INFO] Access URLs:"
echo "[INFO] - FoundryVTT: http://${DUCKDNS_DOMAIN}.duckdns.org:${FOUNDRY_PORT_PUBLIC:-29000}"
echo "[INFO] - FoundryVTT: https://${DUCKDNS_DOMAIN}.duckdns.org:${FOUNDRY_PORT_PUBLIC:-29000} (if SSL configured)"
echo "[INFO]"
echo "[INFO] Next Steps:"
echo "[INFO] 1. Configure your router to forward port ${FOUNDRY_PORT_PUBLIC:-29000} to this Pi"
echo "[INFO] 2. Test external access from outside your network"
echo "[INFO] 3. Consider setting up SSL/TLS for HTTPS access"
echo "[INFO] =============================================="
