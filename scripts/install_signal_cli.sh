#!/bin/bash
mkdir -p ~/signal-cli
cd ~/signal-cli
curl -LO https://github.com/AsamK/signal-cli/releases/download/v0.10.16/signal-cli-0.10.16-Linux.tar.gz
tar xzf signal-cli-0.10.16-Linux.tar.gz
sudo ln -sf ~/signal-cli/bin/signal-cli /usr/bin/signal-cli
echo "Signal CLI installed."