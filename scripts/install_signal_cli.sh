#!/bin/bash
# =============================================================================
#  install_signal_cli.sh - Install Signal CLI for Raspberry Pi FoundryVTT Setup
#
#  Author: Arch-Node Project
#  Purpose:
#    - Install latest stable Signal CLI
#    - Allow server to send and receive Signal messages
#
#  Usage:
#    ./scripts/install_signal_cli.sh
#
#  Notes:
#    - Designed for ARM Linux (Raspberry Pi)
#    - Requires sudo/root access
# =============================================================================

set -e

echo "[INFO] Checking if Signal CLI is already installed..."
if command -v signal-cli >/dev/null 2>&1; then
    echo "[INFO] Signal CLI is already installed. Skipping installation."
    exit 0
fi

echo "[INFO] Installing Java runtime if missing..."
sudo apt-get install -y openjdk-11-jre

echo "[INFO] Fetching latest Signal CLI version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/AsamK/signal-cli/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
SIGNAL_CLI_ARCHIVE="signal-cli-${LATEST_VERSION}-Linux-arm.tar.gz"
SIGNAL_CLI_URL="https://github.com/AsamK/signal-cli/releases/download/v${LATEST_VERSION}/${SIGNAL_CLI_ARCHIVE}"

echo "[INFO] Downloading Signal CLI version ${LATEST_VERSION}..."
wget "$SIGNAL_CLI_URL"

echo "[INFO] Extracting Signal CLI..."
tar xf "$SIGNAL_CLI_ARCHIVE"

echo "[INFO] Installing Signal CLI to /opt/signal-cli..."
sudo mv "signal-cli-${LATEST_VERSION}-Linux-arm" /opt/signal-cli
sudo ln -sf /opt/signal-cli/bin/signal-cli /usr/local/bin/signal-cli

echo "[INFO] Cleaning up installer archive..."
rm -f "$SIGNAL_CLI_ARCHIVE"

echo "[INFO] Signal CLI installation complete. Version: ${LATEST_VERSION}"

# Load Signal environment variables
if [ -f ../env/signal.env ]; then
    source ../env/signal.env
elif [ -f ./env/signal.env ]; then
    source ./env/signal.env
else
    echo "[WARNING] signal.env not found. Manual Signal CLI configuration will be required."
    echo "[INFO] Please run the following commands to configure Signal CLI:"
    echo "  1. signal-cli -u +YOUR_NUMBER register"
    echo "  2. signal-cli -u +YOUR_NUMBER verify CODE_FROM_SMS"
    echo "  3. signal-cli -u +YOUR_NUMBER receive"
    exit 0
fi

echo "[INFO] Configuring Signal CLI with user: ${SIGNAL_CLI_USER}"

# Check if Signal CLI user is already registered
if signal-cli -u "$SIGNAL_CLI_USER" listIdentities >/dev/null 2>&1; then
    echo "[INFO] Signal CLI user ${SIGNAL_CLI_USER} is already registered."
else
    echo "[INFO] Signal CLI user not registered. Starting registration process..."
    echo "[NOTICE] =============================================="
    echo "[NOTICE] MANUAL STEP REQUIRED:"
    echo "[NOTICE] 1. Register your number with Signal CLI:"
    echo "[NOTICE]    signal-cli -u ${SIGNAL_CLI_USER} register"
    echo "[NOTICE] 2. You will receive an SMS with a verification code"
    echo "[NOTICE] 3. Verify with the code:"
    echo "[NOTICE]    signal-cli -u ${SIGNAL_CLI_USER} verify CODE_FROM_SMS"
    echo "[NOTICE] 4. Test receiving messages:"
    echo "[NOTICE]    signal-cli -u ${SIGNAL_CLI_USER} receive"
    echo "[NOTICE] =============================================="
    echo ""
    read -p "Press ENTER when you have completed the registration steps above..."
    
    # Verify registration was successful
    if signal-cli -u "$SIGNAL_CLI_USER" listIdentities >/dev/null 2>&1; then
        echo "[INFO] Signal CLI registration verified successfully!"
    else
        echo "[WARNING] Signal CLI registration could not be verified."
        echo "[WARNING] You may need to complete the registration manually."
    fi
fi

# Create Signal CLI service for background message listening
echo "[INFO] Creating Signal CLI daemon service..."
sudo tee /etc/systemd/system/signal-cli.service > /dev/null <<EOF
[Unit]
Description=Signal CLI Daemon
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/signal-cli
ExecStart=/usr/local/bin/signal-cli -u ${SIGNAL_CLI_USER} daemon --receive-mode on-connection
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create Signal listener service for command processing
echo "[INFO] Creating Signal listener service..."
sudo tee /etc/systemd/system/signal-listener.service > /dev/null <<EOF
[Unit]
Description=Signal Command Listener for FoundryVTT
After=network.target signal-cli.service
Requires=signal-cli.service

[Service]
Type=simple
User=root
WorkingDirectory=$(pwd | sed 's|/scripts||')
ExecStart=/usr/bin/python3 python/signal_listener.py
Restart=always
RestartSec=15
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Set up log rotation for Signal CLI
echo "[INFO] Setting up Signal CLI log rotation..."
sudo tee /etc/logrotate.d/signal-cli > /dev/null <<EOF
/var/log/signal-cli/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

# Create log directory
sudo mkdir -p /var/log/signal-cli

# Enable and start Signal CLI daemon
echo "[INFO] Enabling Signal CLI daemon..."
sudo systemctl daemon-reload
sudo systemctl enable signal-cli.service

# Enable Signal listener service (but don't start yet - wait for full setup)
sudo systemctl enable signal-listener.service

# Test Signal CLI installation
echo "[INFO] Testing Signal CLI installation..."
if signal-cli --version >/dev/null 2>&1; then
    echo "[INFO] Signal CLI is working correctly."
    
    # Test if we can connect (don't start daemon yet)
    if [ -n "$SIGNAL_CLI_USER" ]; then
        echo "[INFO] Testing Signal CLI connectivity..."
        if timeout 10 signal-cli -u "$SIGNAL_CLI_USER" receive --timeout 1 >/dev/null 2>&1 || true; then
            echo "[INFO] Signal CLI connectivity test completed."
        fi
    fi
else
    echo "[ERROR] Signal CLI installation verification failed!"
    exit 1
fi

# Create helper script for manual Signal operations
echo "[INFO] Creating Signal CLI helper script..."
sudo tee /usr/local/bin/foundry-signal > /dev/null <<EOF
#!/bin/bash
# Helper script for FoundryVTT Signal operations

SIGNAL_USER="${SIGNAL_CLI_USER}"

case "\$1" in
    "register")
        echo "Registering Signal CLI user: \$SIGNAL_USER"
        signal-cli -u "\$SIGNAL_USER" register
        ;;
    "verify")
        if [ -z "\$2" ]; then
            echo "Usage: foundry-signal verify CODE"
            exit 1
        fi
        signal-cli -u "\$SIGNAL_USER" verify "\$2"
        ;;
    "test")
        echo "Testing Signal CLI connectivity..."
        signal-cli -u "\$SIGNAL_USER" receive --timeout 5
        ;;
    "send")
        if [ -z "\$2" ]; then
            echo "Usage: foundry-signal send 'message'"
            exit 1
        fi
        signal-cli -u "\$SIGNAL_USER" send --message "\$2" --receiver-group "${SIGNAL_GROUP_ID}"
        ;;
    "status")
        echo "Signal CLI Service Status:"
        systemctl status signal-cli.service
        echo ""
        echo "Signal Listener Service Status:"
        systemctl status signal-listener.service
        ;;
    "logs")
        echo "Recent Signal CLI logs:"
        journalctl -u signal-cli.service -n 20 --no-pager
        ;;
    *)
        echo "FoundryVTT Signal CLI Helper"
        echo "Usage: foundry-signal {register|verify CODE|test|send 'message'|status|logs}"
        ;;
esac
EOF

sudo chmod +x /usr/local/bin/foundry-signal

echo "[INFO] =============================================="
echo "[INFO] Signal CLI installation and configuration complete!"
echo "[INFO] =============================================="
echo "[INFO]"
echo "[INFO] Next steps:"
echo "[INFO] 1. If not already done, complete registration:"
echo "[INFO]    foundry-signal register"
echo "[INFO]    foundry-signal verify CODE_FROM_SMS"
echo "[INFO] 2. Test Signal CLI:"
echo "[INFO]    foundry-signal test"
echo "[INFO] 3. Start Signal services (done automatically by setup.sh):"
echo "[INFO]    sudo systemctl start signal-cli.service"
echo "[INFO]    sudo systemctl start signal-listener.service"
echo "[INFO] 4. Check status anytime:"
echo "[INFO]    foundry-signal status"
echo "[INFO]"
echo "[INFO] Helper commands available:"
echo "[INFO] - foundry-signal register"
echo "[INFO] - foundry-signal verify CODE"
echo "[INFO] - foundry-signal test"
echo "[INFO] - foundry-signal send 'message'"
echo "[INFO] - foundry-signal status"
echo "[INFO] - foundry-signal logs"
echo "[INFO] =============================================="
