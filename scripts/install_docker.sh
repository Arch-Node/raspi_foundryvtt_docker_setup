#!/bin/bash
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
echo "Docker installed."