#!/bin/bash
# =============================================================================
#  setup_duckdns.sh - Setup DuckDNS Updater for Dynamic IP Resolution
#
#  Author: Arch-Node Project
#  Purpose:
#    - Configure automatic IP updates with DuckDNS
#
#  Usage:
#    ./scripts/setup_duckdns.sh
#
# =============================================================================

set -e

# Load environment variables
if [ -f ./env/duckdns.env ]; then
  export $(grep -v '^#' ./env/duckdns.env | xargs)
else
  echo "[ERROR] Missing env/duckdns.env. Cannot configure DuckDNS."
  exit 1
fi

echo "[INFO] Setting up DuckDNS for domain: $DUCKDNS_DOMAIN"

# Create folder for DuckDNS script
sudo mkdir -p /opt/duckdns

# Create update script
sudo tee /opt/duckdns/duck.sh >/dev/null <<EOF
#!/bin/bash
curl -k "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip="
EOF

# Make script executable
sudo chmod 700 /opt/duckdns/duck.sh

echo "[INFO] DuckDNS updater script created at /opt/duckdns/duck.sh"

# Create systemd service
sudo tee /etc/systemd/system/duckdns.service >/dev/null <<EOF
[Unit]
Description=DuckDNS Update Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/duckdns/duck.sh
EOF

# Create systemd timer
sudo tee /etc/systemd/system/duckdns.timer >/dev/null <<EOF
[Unit]
Description=Run DuckDNS update script every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=duckdns.service

[Install]
WantedBy=timers.target
EOF

# Reload systemd and start timer
sudo systemctl daemon-reload
sudo systemctl enable duckdns.timer
sudo systemctl start duckdns.timer

echo "[INFO] DuckDNS updater systemd timer is active and running."
