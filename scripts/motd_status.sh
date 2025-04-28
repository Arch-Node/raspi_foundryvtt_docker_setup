#!/bin/bash
echo "Server Uptime:"
uptime -p
echo "Disk Space:"
df -h /backups | tail -n 1