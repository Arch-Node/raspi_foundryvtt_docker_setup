#!/bin/bash
echo "nameserver 208.67.222.222" | sudo tee /etc/resolv.conf > /dev/null
echo "nameserver 208.67.220.220" | sudo tee -a /etc/resolv.conf > /dev/null
echo "Configured OpenDNS."