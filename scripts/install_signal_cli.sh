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
